@extends('admin.layout')
@section('title', $a['name'])
@section('nav', '1')
@section('content')
<p style="margin-top:0"><a href="/admin/accounts" style="font-weight:700">← Accounts</a></p>
<div class="grid c2">
  <div class="card">
    <div style="display:flex;align-items:center;gap:14px;margin-bottom:12px">
      <span class="tile" style="width:52px;height:52px;border-radius:16px;background:var(--peach);display:grid;place-items:center;font-weight:800;font-size:20px">{{ mb_strtoupper(mb_substr($a['name'], 0, 1)) }}</span>
      <div>
        <div style="font-weight:800;font-size:18px">{{ $a['name'] }}</div>
        <div class="muted">{{ $a['email'] }}</div>
      </div>
      <span class="pill {{ $a['status'] === 'deletion pending' ? 'deletion' : $a['status'] }}" style="margin-left:auto">{{ $a['status'] }}</span>
    </div>
    <table>
      <tr><th scope="row">Timezone</th><td>{{ $a['timezone'] }}</td></tr>
      <tr><th scope="row">Joined (UTC)</th><td class="mono">{{ $a['joined'] }}</td></tr>
      <tr><th scope="row">Devices signed in</th><td>{{ count($a['devices']) }}</td></tr>
    </table>
    <p class="muted" style="margin-bottom:0">Account details only. Habits, check-ins, notes, rewards, photos and exports are never shown here.</p>
  </div>

  @if ($a['status'] !== 'deletion pending')
  <div class="card">
    <h3 style="margin:0 0 6px">Manage</h3>
    <p class="muted" style="margin-top:0">Each action is recorded in the activity log.</p>
    <div class="actions">
      <form method="post" action="/admin/accounts/{{ $a['id'] }}/sign-out" class="inline">@csrf<button class="secondary" type="submit">Sign out all devices</button></form>
      @if ($a['status'] === 'suspended')
        <form method="post" action="/admin/accounts/{{ $a['id'] }}/resume" class="inline">@csrf<button type="submit">Resume</button></form>
      @else
        <form method="post" action="/admin/accounts/{{ $a['id'] }}/suspend" class="inline">@csrf<button class="secondary" type="submit">Suspend</button></form>
      @endif
      <a class="button secondary" href="/admin/notices?to={{ urlencode($a['email']) }}">Send a notice</a>
    </div>
    <p class="muted">Suspending signs them out and refuses sign-in until you resume. Their data is untouched.</p>
  </div>
  @endif
</div>

<h2>Devices signed in</h2>
<div class="table">
  <table>
    <thead><tr><th scope="col">Device</th><th scope="col">Last used (UTC)</th><th scope="col">Signed in since (UTC)</th></tr></thead>
    <tbody>
    @forelse ($a['devices'] as $d)
      <tr><td><b>{{ $d['name'] }}</b></td><td class="mono muted">{{ $d['last_used'] ?? '–' }}</td><td class="mono muted">{{ $d['since'] }}</td></tr>
    @empty
      <tr><td colspan="3" class="empty">No devices signed in.</td></tr>
    @endforelse
    </tbody>
  </table>
</div>

@if ($a['status'] !== 'deletion pending')
<h2>Delete this account</h2>
<form method="post" action="/admin/accounts/{{ $a['id'] }}/delete" class="card" style="border:1px solid var(--err-bg)">
  @csrf
  <p class="muted" style="margin-top:0">Starts the same deletion the app offers: signed out now, everything purged within 30 days. This cannot be undone.</p>
  <label for="confirm_email">Type {{ $a['email'] }} to confirm</label>
  <input id="confirm_email" name="confirm_email" autocomplete="off" required>
  <p style="margin-bottom:0"><button class="danger" type="submit">Delete account</button></p>
</form>
@endif
@endsection
