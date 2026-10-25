<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Exports\ExportStore;
use App\Application\Exports\OpenExports;
use App\Application\Journal\ChangeJournal;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Http\Responses\ApiResponse;
use App\Jobs\RunExportJob;
use App\Models\User;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use stdClass;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * A48: export jobs. Not domain writes: nothing is journaled and nothing goes through /sync.
 * Owner-scoped: another user's job, or a missing one, is the same 404.
 */
final class ExportController
{
    public const int LIST_LIMIT = 5;

    public function __construct(
        private readonly ExportStore $store,
        private readonly Clock $clock,
        private readonly ChangeJournal $journal,
    ) {}

    /**
     * POST /exports {format} -> 202. A live queued or running job of that format is returned
     * instead; a stale one (OpenExports) is passed over.
     */
    public function store(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $data = Validator::make($request->only('format'), ['format' => ['required', Rule::in(['json', 'csv'])]])->validate();
        $format = (string) $data['format'];

        $job = DB::transaction(function () use ($user, $format) {
            // The user row lock keeps two requests from both starting a job (and a deleted
            // account from starting one, A49).
            $this->journal->lockUser((string) $user->id);
            $open = OpenExports::live(DB::table('export_jobs')->where('user_id', $user->id)->where('format', $format), $this->clock->now())
                ->orderByDesc('created_at')->first();
            if ($open !== null) {
                return $open;
            }
            $now = UtcTime::format($this->clock->now());
            $id = (string) Str::uuid7();
            DB::table('export_jobs')->insert([
                'id' => $id, 'user_id' => $user->id, 'format' => $format, 'status' => 'queued',
                'created_at' => $now, 'updated_at' => $now,
            ]);
            RunExportJob::dispatch($id)->afterCommit();

            return DB::table('export_jobs')->where('id', $id)->first();
        });

        return ApiResponse::success($this->present($job ?? throw new \LogicException('Job vanished.')), 202);
    }

    /** GET /exports: the 5 newest jobs, newest first. */
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $jobs = DB::table('export_jobs')->where('user_id', $user->id)
            ->orderByDesc('created_at')->orderByDesc('id')->limit(self::LIST_LIMIT)->get();

        return ApiResponse::success($jobs->map(fn ($j) => $this->present($j))->values()->all());
    }

    /** GET /exports/{id} */
    public function show(Request $request, string $export): JsonResponse
    {
        return ApiResponse::success($this->present($this->owned($request, $export)));
    }

    /**
     * GET /exports/{id}/download: signed, and also the session's owner. Checks in order: owner
     * (404), expiry (410 export_expired), signature (403).
     */
    public function download(Request $request, string $export): StreamedResponse
    {
        $job = $this->owned($request, $export);
        if ($job->status === 'expired' || ($job->status === 'ready' && $this->expired($job))) {
            throw ApiException::exportExpired();
        }
        if ($job->status !== 'ready' || $job->object_key === null) {
            throw new ApiException(404, 'not_found', 'Not found.');
        }
        if (! URL::hasValidSignature($request, absolute: false)) {
            throw new ApiException(403, 'forbidden', 'This link is not valid.');
        }
        $stream = $this->store->stream((string) $job->user_id, (string) $job->object_key)
            ?? throw new ApiException(404, 'not_found', 'Not found.');
        $extension = $job->format === 'csv' ? 'csv' : 'zip';

        return response()->stream(function () use ($stream) {
            fpassthru($stream);
            fclose($stream);
        }, 200, [
            'Content-Type' => $job->format === 'csv' ? 'text/csv; charset=utf-8' : 'application/zip',
            'Content-Disposition' => 'attachment; filename="habit-export.'.$extension.'"',
            'Cache-Control' => 'private, no-store',
        ]);
    }

    private function owned(Request $request, string $export): stdClass
    {
        /** @var User $user */
        $user = $request->user();
        $job = Str::isUuid($export)
            ? DB::table('export_jobs')->where('id', strtolower($export))->where('user_id', $user->id)->first()
            : null;

        return $job ?? throw new ApiException(404, 'not_found', 'Not found.');
    }

    private function expired(stdClass $job): bool
    {
        return $job->expires_at !== null && WireTime::parse((string) $job->expires_at) <= $this->clock->now();
    }

    /** @return array<string, mixed> */
    private function present(stdClass $job): array
    {
        $ready = $job->status === 'ready' && ! $this->expired($job);
        $expiresAt = $job->expires_at === null ? null : WireTime::parse((string) $job->expires_at);

        return [
            'id' => (string) $job->id,
            'format' => (string) $job->format,
            // A ready job past its 24 hours reads as expired before the sweep catches it.
            'status' => $job->status === 'ready' && ! $ready ? 'expired' : (string) $job->status,
            'requested_at' => UtcTime::format(WireTime::parse((string) $job->created_at)),
            'snapshot_seq' => $job->snapshot_seq === null ? null : (int) $job->snapshot_seq,
            'expires_at' => $expiresAt === null ? null : UtcTime::format($expiresAt),
            // Signed without the host, so a proxy or the emulator's address still matches.
            'download_url' => $ready && $expiresAt !== null
                ? url(URL::temporarySignedRoute('exports.download', $expiresAt, ['export' => $job->id], absolute: false))
                : null,
            'error_code' => $job->error_code,
        ];
    }
}
