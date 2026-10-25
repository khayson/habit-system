<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/** A50: the reset code email. Plain text and simple HTML; no link of any kind. */
final class PasswordResetCodeMail extends Mailable
{
    use Queueable;

    public function __construct(public readonly string $code) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'Your password reset code');
    }

    public function content(): Content
    {
        return new Content(html: 'mail.reset-code', text: 'mail.reset-code-text', with: ['code' => $this->code]);
    }
}
