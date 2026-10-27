@extends('admin.layout')
@section('title', 'Notices')
@section('nav', '1')
@section('content')
<div class="grid c2">
  <form method="post" action="/admin/notices" class="card">
    @csrf
    <h3 style="margin:0 0 4px">New notice</h3>
    <p class="muted" style="margin-top:0">Shown in the app's Today carousel. Plain text and calm wording: no pressure, no loss threats.</p>
    <label for="title">Title <span class="muted">(up to 60 characters)</span></label>
    <input id="title" name="title" maxlength="60" value="{{ old('title') }}" required>
    <label for="body">Message <span class="muted">(up to 280 characters)</span></label>
    <textarea id="body" name="body" maxlength="280" required>{{ old('body') }}</textarea>
    <label for="to">For <span class="muted">(account emails, one per line; empty means everyone)</span></label>
    <textarea id="to" name="to" style="min-height:64px">{{ old('to', $to) }}</textarea>
    <label for="ends">Ends <span class="muted">(optional, UTC)</span></label>
    <input id="ends" name="ends" type="datetime-local" value="{{ old('ends') }}">
    <p style="margin-bottom:0"><button type="submit">Publish</button></p>
  </form>

  <div>
    <h3 style="margin:4px 0 10px">How it looks in the app</h3>
    <div class="card" style="background:var(--lime);display:flex;gap:12px;align-items:flex-start">
      <span style="width:44px;height:44px;border-radius:14px;background:var(--surface);display:grid;place-items:center;flex:none">
        <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true" style="stroke:var(--ink);fill:none;stroke-width:1.8"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01" stroke-linecap="round"/></svg>
      </span>
      <div>
        <div style="font-size:13px;font-weight:600">From the Habit team</div>
        <div style="font-weight:800;font-size:17px">{{ old('title') ?: 'Your title appears here' }}</div>
        <div style="font-size:14px">{{ old('body') ?: 'Your message appears under it, on the Today screen, until it ends or the person dismisses it.' }}</div>
      </div>
    </div>
    <p class="muted">The app shows at most 5 notices, newest first, and checks for new ones every 15 minutes.</p>
  </div>
</div>

<h2>All notices</h2>
<div class="table">
  <table>
    <thead><tr><th scope="col">Title</th><th scope="col">For</th><th scope="col">Status</th><th scope="col">Starts (UTC)</th><th scope="col">Ends (UTC)</th><th scope="col"><span class="muted">Actions</span></th></tr></thead>
    <tbody>
    @forelse ($notices as $n)
      @php $live = $n['starts_at'] <= $now && ($n['ends_at'] === null || $n['ends_at'] > $now); $later = $n['starts_at'] > $now; @endphp
      <tr>
        <td><b>{{ $n['title'] }}</b></td>
        <td>{{ $n['audience'] }}</td>
        <td><span class="pill {{ $live ? 'ok' : ($later ? 'warn' : 'err') }}">{{ $live ? 'Showing' : ($later ? 'Scheduled' : 'Ended') }}</span></td>
        <td class="mono muted">{{ $n['starts_at'] }}</td>
        <td class="mono muted">{{ $n['ends_at'] ?? '–' }}</td>
        <td>
          @if ($live || $later)
            <form method="post" action="/admin/notices/{{ $n['id'] }}/retire" class="inline">@csrf<button class="ghost" type="submit">Retire</button></form>
          @endif
        </td>
      </tr>
    @empty
      <tr><td colspan="6" class="empty">No notices yet.</td></tr>
    @endforelse
    </tbody>
  </table>
</div>
@endsection
