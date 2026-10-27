<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Mail\Mailables\Headers;
use Illuminate\Support\Facades\URL;

/**
 * A59: a service announcement. Plain text and simple HTML; no images, no tracking, no link
 * rewriting. Each one carries a signed stop link and RFC 8058 one-click unsubscribe headers.
 * Without a user (the admin's test), the link is described, not made.
 */
final class AnnouncementMail extends Mailable
{
    use Queueable;

    public function __construct(
        public readonly string $subjectLine,
        public readonly string $text,
        public readonly ?string $userId,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: $this->subjectLine);
    }

    public function headers(): Headers
    {
        if ($this->userId === null) {
            return new Headers;
        }

        return new Headers(text: [
            'List-Unsubscribe' => '<'.$this->stopUrl().'>',
            'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click',
        ]);
    }

    public function content(): Content
    {
        $paragraphs = array_values(array_filter(array_map('trim', preg_split("/\n\s*\n/", $this->text) ?: [])));

        return new Content(html: 'mail.announcement', text: 'mail.announcement-text', with: [
            'paragraphs' => $paragraphs,
            'plain' => $this->text,
            'stopUrl' => $this->userId === null ? null : $this->stopUrl(),
        ]);
    }

    private function stopUrl(): string
    {
        return URL::signedRoute('emails.stop', ['user' => $this->userId]);
    }
}
