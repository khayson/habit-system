<?php

namespace App\Http\Requests;

use App\Domain\Calendar\CalendarEntry;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/** POST /auth/register: name, email, password, timezone, device_name (+ optional device_id). */
final class RegisterRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:80'],
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'max:255', self::passwordRule()],
            'timezone' => ['required', 'string', 'max:64', function (string $attribute, mixed $value, Closure $fail) {
                if (! is_string($value) || ! CalendarEntry::isIanaZone($value)) {
                    $fail('Choose a valid time zone.');
                }
            }],
            'device_name' => ['required', 'string', 'max:255'],
            'device_id' => ['nullable', 'uuid'],
        ];
    }

    /** Spec: at least 12 characters; A16: reject known-breached passwords. */
    public static function passwordRule(): Password
    {
        $rule = Password::min(12);

        return config()->boolean('auth.password_breach_check') ? $rule->uncompromised() : $rule;
    }
}
