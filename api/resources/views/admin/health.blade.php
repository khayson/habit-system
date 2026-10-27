@extends('admin.layout')
@section('title', 'Health & jobs')
@section('nav', '1')
@section('top-actions')
  <form method="post" action="/admin/server/tick" class="inline">@csrf<button type="submit">Run the timer now</button></form>
@endsection
@section('content')
@php
  $tickOk = $s['last_tick_at'] !== null;
  $db = $s['database'];
@endphp
<div class="grid k4">
  <div class="kpi">
    <div class="label">Timer</div>
    <div><span class="pill {{ $tickOk ? 'ok' : 'warn' }}">{{ $tickOk ? 'Running' : 'Never ran' }}</span></div>
    <div class="delta">Last ran <b class="mono">{{ $s['last_tick_at'] ?? 'never' }}</b> UTC. The outside timer calls it every 5 minutes.</div>
  </div>
  <div class="kpi">
    <div class="label">Jobs waiting</div>
    <div class="value mono">{{ $s['queue']['waiting'] }}</div>
    <div class="delta">{{ $s['queue']['oldest_waiting_seconds'] === null ? 'Nothing queued.' : 'Oldest waiting '.$s['queue']['oldest_waiting_seconds'].' s.' }}</div>
  </div>
  <div class="kpi">
    <div class="label">Jobs failed</div>
    <div class="value mono">{{ $s['queue']['failed'] }}</div>
    <div><span class="pill {{ $s['queue']['failed'] === 0 ? 'ok' : 'err' }}">{{ $s['queue']['failed'] === 0 ? 'None' : 'Needs a look' }}</span></div>
  </div>
  <div class="kpi">
    <div class="label">Reset-email failures, 7 days</div>
    <div class="value mono">{{ $s['mail_failures']['last_7_days'] }}</div>
    <div class="delta">{{ $s['mail_failures']['last_at'] === null ? 'None recorded.' : 'Last at '.$s['mail_failures']['last_at'].' UTC.' }}</div>
  </div>
</div>

<h2>Database</h2>
<div class="card">
  <div style="display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:10px">
    <b>{{ round($db['size_bytes'] / 1048576, 1) }} MB of {{ round($db['limit_bytes'] / 1048576) }} MB</b>
    <span class="pill {{ $db['used_percent'] < 60 ? 'ok' : ($db['used_percent'] < 80 ? 'warn' : 'err') }}">{{ $db['used_percent'] }}% used</span>
  </div>
  <div class="meter" role="img" aria-label="{{ $db['used_percent'] }} percent of the database limit used"><span style="width:{{ min(100, $db['used_percent']) }}%"></span></div>
  <p class="muted" style="margin-bottom:0">Neon's free tier allows 0.5 GB. Plan an upgrade well before 80%. The app accepts builds from {{ $s['min_app_version'] }} up.</p>
</div>

<h2>Failed jobs</h2>
<p class="sub">Only the job's type and the error's kind are shown, never the job's contents.</p>
@if (count($jobs['failed']) > 0)
<div class="actions" style="margin-bottom:12px">
  <form method="post" action="/admin/server/retry-jobs" class="inline">@csrf<button class="secondary" type="submit">Retry all</button></form>
  <form method="post" action="/admin/health/failed/forget-all" class="inline">@csrf<button class="ghost" type="submit">Clear the list</button></form>
</div>
@endif
<div class="table">
  <table>
    <thead><tr><th scope="col">Job</th><th scope="col">Error</th><th scope="col">Failed (UTC)</th><th scope="col"><span class="muted">Actions</span></th></tr></thead>
    <tbody>
    @forelse ($jobs['failed'] as $j)
      <tr>
        <td><b>{{ $j['job'] }}</b> <span class="muted">· {{ $j['queue'] }}</span></td>
        <td>{{ $j['error'] }}</td>
        <td class="mono muted">{{ $j['at'] }}</td>
        <td class="actions">
          <form method="post" action="/admin/health/failed/{{ $j['uuid'] }}/retry" class="inline">@csrf<button class="ghost" type="submit">Retry</button></form>
          <form method="post" action="/admin/health/failed/{{ $j['uuid'] }}/forget" class="inline">@csrf<button class="ghost" type="submit">Remove</button></form>
        </td>
      </tr>
    @empty
      <tr><td colspan="4" class="empty">No failed jobs.</td></tr>
    @endforelse
    </tbody>
  </table>
</div>

<h2>Jobs waiting</h2>
<div class="table">
  <table>
    <thead><tr><th scope="col">Job</th><th scope="col">Queue</th><th scope="col" class="num">Tries</th><th scope="col">Queued (UTC)</th></tr></thead>
    <tbody>
    @forelse ($jobs['waiting'] as $j)
      <tr><td><b>{{ $j['job'] }}</b></td><td class="muted">{{ $j['queue'] }}</td><td class="num">{{ $j['attempts'] }}</td><td class="mono muted">{{ $j['since'] }}</td></tr>
    @empty
      <tr><td colspan="4" class="empty">Nothing waiting. The timer runs the queue until it is empty.</td></tr>
    @endforelse
    </tbody>
  </table>
</div>
@endsection
