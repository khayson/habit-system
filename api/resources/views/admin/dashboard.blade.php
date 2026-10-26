@extends('admin.layout')
@section('title', 'System')
@section('nav', '1')
@section('content')
<h1>System</h1>
<div class="grid">
  <div class="stat"><b>{{ $s['accounts']['live'] }}</b><span>Live accounts</span></div>
  <div class="stat"><b>{{ $s['accounts']['deletions_pending'] }}</b><span>Deletions pending</span></div>
  <div class="stat"><b>{{ $s['check_ins_last_24h'] }}</b><span>Check-ins, last 24 hours</span></div>
  <div class="stat"><b>{{ $s['queue']['waiting'] }}</b><span>Jobs waiting @if($s['queue']['oldest_waiting_seconds'] !== null)(oldest {{ $s['queue']['oldest_waiting_seconds'] }} s)@endif</span></div>
  <div class="stat"><b>{{ $s['queue']['failed'] }}</b><span>Jobs failed</span></div>
  <div class="stat"><b>{{ $s['last_tick_at'] ?? 'never' }}</b><span>Timer last ran (UTC)</span></div>
  <div class="stat"><b>{{ $s['mail_failures']['last_7_days'] }}</b><span>Reset-email failures, 7 days</span></div>
  <div class="stat"><b>{{ $s['database']['used_percent'] }}%</b><span>Database used ({{ round($s['database']['size_bytes'] / 1048576, 1) }} MB of {{ round($s['database']['limit_bytes'] / 1048576) }} MB)</span></div>
  <div class="stat"><b>{{ $s['min_app_version'] }}</b><span>Lowest app build accepted</span></div>
</div>

<h2>Server</h2>
<div class="card">
  <form method="post" action="/admin/server/tick" class="inline">@csrf<button type="submit">Run the timer now</button></form>
  <form method="post" action="/admin/server/retry-jobs" class="inline">@csrf<button class="secondary" type="submit">Retry failed jobs</button></form>
  <p class="muted">The timer runs scheduled work and the job queue; the outside timer calls it every few minutes anyway.</p>
</div>

<h2>Recent admin actions</h2>
<table>
  <thead><tr><th scope="col">When (UTC)</th><th scope="col">Action</th><th scope="col">Subject</th><th scope="col">Detail</th></tr></thead>
  <tbody>
  @forelse ($actions as $a)
    <tr><td>{{ $a['at'] }}</td><td>{{ $a['action'] }}</td><td class="muted">{{ $a['subject'] ?? '–' }}</td><td class="muted">{{ $a['detail'] }}</td></tr>
  @empty
    <tr><td colspan="4" class="muted">Nothing yet.</td></tr>
  @endforelse
  </tbody>
</table>
@endsection
