<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * POST /auth/reset-password: email, reset_token (the 6-digit code), password and its
 * confirmation, with registration's password rules (A50, A16). The code's format is not checked
 * here: any wrong code gets the same answer from the service.
 */
final class ResetPasswordRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if (is_string($this->input('email'))) {
            $this->merge(['email' => mb_strtolower(trim($this->input('email')))]);
        }
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'max:255'],
            'reset_token' => ['required', 'string', 'max:32'],
            'password' => ['required', 'string', 'max:255', 'confirmed', RegisterRequest::passwordRule()],
        ];
    }
}
