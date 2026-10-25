<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** DELETE /me: the password, as the recent reauthentication (A49). */
final class DeleteAccountRequest extends FormRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'password' => ['required', 'string', 'max:255'],
        ];
    }
}
