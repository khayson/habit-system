@extends('admin.layout')
@section('title', 'Notices')
@section('nav', '1')
@section('content')
<h1>Notices</h1>
<form method="post" action="/admin/notices" class="card">
  @csrf
  <p class="muted">Shown in the app's Today carousel. Plain text, calm wording: no pressure, no loss threats.</p>
  <label for="title">Title (up to 60 characters)</label>
  <input id="title" name="title" maxlength="60" value="{{ old('title') }}" required>
  <label for="body">Message (up to 280 characters)</label>
  <textarea id="body" name="body" maxlength="280" required>{{ old('body') }}</textarea>
  <label for="to">For (account emails, one per line; leave empty for everyone)</label>
  <textarea id="to" name="to" style="min-height:64px">{{ old('to', $to) }}</textarea>
  <label for="ends">Ends (optional, UTC)</label>
  <input id="ends" name="ends" type="datetime-local" value="{{ old('ends') }}">
  <p><button type="submit">Publish</button></p>
</form>

<h2>All notices</h2>
<table>
  <thead><tr><th scope="col">Title</th><th scope="col">For</th><th scope="col">Starts (UTC)</th><th scope="col">Ends (UTC)</th><th scope="col"></th></tr></thead>
  <tbody>
  @forelse ($notices as $n)
    <tr>
      <td>{{ $n['title'] }}</td>
      <td>{{ $n['audience'] }}</td>
      <td class="muted">{{ $n['starts_at'] }}</td>
      <td class="muted">{{ $n['ends_at'] ?? '–' }}</td>
      <td>
        @if ($n['ends_at'] === null || $n['ends_at'] > $now)
          <form method="post" action="/admin/notices/{{ $n['id'] }}/retire" class="inline">@csrf<button class="secondary" type="submit">Retire</button></form>
        @endif
      </td>
    </tr>
  @empty
    <tr><td colspan="5" class="muted">No notices yet.</td></tr>
  @endforelse
  </tbody>
</table>
@endsection
