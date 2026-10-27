@extends('admin.layout')
@section('title', 'New announcement')
@section('nav', '1')
@section('content')
<p style="margin-top:0"><a href="/admin/emails" style="font-weight:700">← Emails</a></p>
<div class="grid c2">
  <form method="post" action="/admin/emails" class="card">
    @csrf
    <label for="subject">Subject <span class="muted">(up to 120 characters)</span></label>
    <input id="subject" name="subject" maxlength="120" value="{{ old('subject') }}" required>

    <label for="body">Message <span class="muted">(plain text; a blank line starts a paragraph)</span></label>
    <textarea id="body" name="body" maxlength="5000" style="min-height:220px" required>{{ old('body') }}</textarea>
    <p class="muted" style="margin:6px 0 0">Personal fields: <code>{name}</code> and <code>{first_name}</code>. A "stop these emails" link is added at the end.</p>

    <label for="audience">Who it is for</label>
    <select id="audience" name="audience">
      @foreach (['everyone' => 'Everyone', 'active' => 'Active in the last N days', 'inactive' => 'Inactive for N days or more', 'new' => 'Signed up in the last N days', 'emails' => 'Chosen emails'] as $key => $label)
        <option value="{{ $key }}" @selected(old('audience', 'everyone') === $key)>{{ $label }}</option>
      @endforeach
    </select>
    <div class="filters" style="margin:0">
      <div><label for="days">N days <span class="muted">(for active, inactive, new)</span></label><input id="days" name="days" type="number" min="1" max="365" value="{{ old('days', '30') }}"></div>
    </div>
    <label for="emails">Chosen emails <span class="muted">(one per line)</span></label>
    <textarea id="emails" name="emails" style="min-height:64px">{{ old('emails') }}</textarea>
    <p class="muted" style="margin:6px 0 0">Suspended accounts, accounts being deleted and anyone who stopped these emails are always left out.</p>

    <label for="send_at">Send at <span class="muted">(only for Schedule, UTC)</span></label>
    <input id="send_at" name="send_at" type="datetime-local" value="{{ old('send_at') }}">

    <div class="actions" style="margin-top:18px">
      <button type="submit" formaction="/admin/emails/preview" class="secondary">Preview</button>
      <button type="submit" name="action" value="test" class="ghost">Send me a test</button>
      <button type="submit" name="action" value="draft" class="ghost">Save draft</button>
      <button type="submit" name="action" value="schedule" class="secondary">Schedule</button>
      <button type="submit" name="action" value="now">Send now</button>
    </div>
  </form>

  <div>
    <h3 style="margin:4px 0 10px">Preview</h3>
    @if ($preview)
      <div class="card" style="margin-bottom:12px;display:flex;gap:16px;flex-wrap:wrap;align-items:center">
        <span><b class="mono" style="font-size:22px">{{ number_format($preview['reach']) }}</b> <span class="muted">{{ $preview['reach'] === 1 ? 'person' : 'people' }} now</span></span>
        <span class="muted">{{ $preview['audience'] }}</span>
      </div>
      <div class="card" style="background:var(--bg)">
        <p class="muted" style="margin:0 0 6px">As {{ $preview['name'] }} sees it</p>
        <p style="margin:0 0 14px;font-weight:800;font-size:18px">{{ $preview['subject'] }}</p>
        <div class="card" style="box-shadow:none">
          @forelse ($preview['paragraphs'] as $p)
            <p style="margin:0 0 14px">{!! nl2br(e($p)) !!}</p>
          @empty
            <p class="muted" style="margin:0">Write a message to see it here.</p>
          @endforelse
        </div>
        <p class="muted" style="margin:12px 2px 0;font-size:13px">You are getting this because you have a Habit System account. It is a service announcement, not marketing. <u>Stop these emails</u>.</p>
      </div>
    @else
      <div class="card empty">Choose Preview to see the email as a recipient sees it, and how many people it reaches right now.</div>
    @endif
  </div>
</div>
@endsection
