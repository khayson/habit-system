<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Avatars\AvatarService;
use App\Application\Avatars\AvatarStore;
use App\Domain\Avatar\AvatarPipeline;
use App\Domain\Avatar\AvatarRejected;
use App\Exceptions\ApiException;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\File\UploadedFile as SymfonyUploadedFile;
use Throwable;

/**
 * A20: PUT /me/avatar (multipart field "photo", Idempotency-Key), DELETE /me/avatar,
 * GET /me/avatar/{sm|md|lg}. Owner-only: every route acts on the caller's own photo, so there
 * is no id to guess. Never serves the uploaded bytes, only the pipeline's re-encoded squares.
 */
final class AvatarController
{
    public function __construct(private readonly AvatarService $avatars) {}

    public function put(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $key = $request->header('Idempotency-Key');
        if (! is_string($key) || ! Str::isUuid($key)) {
            throw ValidationException::withMessages(['idempotency_key' => ['An Idempotency-Key (a UUID) is required.']]);
        }

        $photo = $request->file('photo') ?? self::parsedPutFile();
        if ($photo instanceof UploadedFile && ! $photo->isValid()) {
            if (in_array($photo->getError(), [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
                throw new ApiException(413, 'payload_too_large', AvatarRejected::tooLarge()->getMessage());
            }
            $photo = null;
        }
        if (! $photo instanceof UploadedFile) {
            throw ValidationException::withMessages(['photo' => ['Choose a photo.']]);
        }
        if ((int) $photo->getSize() > AvatarPipeline::MAX_BYTES) {
            throw new ApiException(413, 'payload_too_large', AvatarRejected::tooLarge()->getMessage());
        }

        try {
            $result = $this->avatars->put($user->id, strtolower($key), (string) $photo->get(), AvatarPipeline::forRuntime());
        } catch (AvatarRejected $e) {
            throw $e->status === 413
                ? new ApiException(413, 'payload_too_large', $e->getMessage())
                : ValidationException::withMessages(['photo' => [$e->getMessage()]]);
        }

        return ApiResponse::success($result);
    }

    public function delete(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return ApiResponse::success($this->avatars->delete($user->id));
    }

    public function show(Request $request, string $size): Response
    {
        /** @var User $user */
        $user = $request->user();
        // An unknown size is the same answer as no photo, and only after authentication.
        $avatar = (in_array($size, AvatarStore::SIZES, true) ? $this->avatars->read($user->id, $size) : null) ?? throw new ApiException(404, 'not_found', 'Not found.');

        $etag = '"'.$avatar['etag'].'"';
        $headers = [
            'Cache-Control' => 'private',
            'ETag' => $etag,
            'X-Content-Type-Options' => 'nosniff',
        ];
        if (in_array($etag, array_map('trim', explode(',', (string) $request->header('If-None-Match'))), true)) {
            return new Response('', 304, $headers);
        }

        return new Response($avatar['bytes'], 200, [...$headers, 'Content-Type' => $avatar['content_type']]);
    }

    /**
     * PHP fills $_FILES only for POST. For a real multipart PUT, PHP 8.4's request_parse_body()
     * parses the body with the same upload limits. Null when there is nothing to parse.
     */
    private static function parsedPutFile(): ?UploadedFile
    {
        if (! function_exists('request_parse_body')) {
            return null;
        }
        try {
            [, $files] = request_parse_body();
        } catch (Throwable) {
            return null;
        }
        $file = $files['photo'] ?? null;
        if (! is_array($file) || ! is_string($file['tmp_name'] ?? null)) {
            return null;
        }

        return UploadedFile::createFromBase(new SymfonyUploadedFile(
            $file['tmp_name'],
            (string) ($file['name'] ?? 'photo'),
            null,
            (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE),
        ));
    }
}
