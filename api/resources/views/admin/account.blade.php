@extends('admin.layout')
@section('title', $a['email'])
@section('nav', '1')
@section('content')
<p><a href="/admin/accounts">← Accounts</a></p>
<h1>{{ $a['name'] }}</h1>
<div class="card">
  <p><b>Email:</b> {{ $a['email'] }}</p>
  <p><b>Status:</b> <span class="pill {{ $a['status'] === 'deletion pending' ? 'deletion' : $a['status'] }}">{{ $a['status'] }}</span></p>
  <p><b>Timezone:</b> {{ $a['timezone'] }}</p>
  <p><b>Joined (UTC):</b> {{ $a['joined'] }}</p>
  <p class="muted">Account details only. Habits, check-ins, notes, rewards, photos and exports are never shown here.</p>
</div>

<h2>Devices signed in</h2>
<table>
  <thead><tr><th scope="col">Device</th><th scope="col">Last used (UTC)</th><th scope="col">Signed in since (UTC)</th></tr></thead>
  <tbody>
  @forelse ($a['devices'] as $d)
    <tr><td>{{ $d['name'] }}</td><td class="muted">{{ $d['last_used'] ?? '–' }}</td><td class="muted">{{ $d['since'] }}</td></tr>
  @empty
    <tr><td colspan="3" class="muted">No devices signed in.</td></tr>
  @endforelse
  </tbody>
</table>

@if ($a['status'] !== 'deletion pending')
<h2>Actions</h2>
<div class="card">
  <form method="post" action="/admin/accounts/{{ $a['id'] }}/sign-out" class="inline">@csrf<button class="secondary" type="submit">Sign out all devices</button></form>
  @if ($a['status'] === 'suspended')
    <form method="post" action="/admin/accounts/{{ $a['id'] }}/resume" class="inline">@csrf<button type="submit">Resume</button></form>
  @else
    <form method="post" action="/admin/accounts/{{ $a['id'] }}/suspend" class="inline">@csrf<button class="secondary" type="submit">Suspend</button></form>
  @endif
  <a href="/admin/notices?to={{ urlencode($a['email']) }}" style="display:inline-block;padding:10px 4px">Send a notice</a>
  <p class="muted">Suspending signs them out and refuses sign-in until you resume. Their data is untouched.</p>
</div>

<h2>Delete this account</h2>
<form method="post" action="/admin/accounts/{{ $a['id'] }}/delete" class="card">
  @csrf
  <p class="muted">Starts the same deletion the app offers: signed out now, everything purged within 30 days.</p>
  <label for="confirm_email">Type {{ $a['email'] }} to confirm</label>
  <input id="confirm_email" name="confirm_email" autocomplete="off" required>
  <p><button class="danger" type="submit">Delete account</button></p>
</form>
@endif
@endsection
