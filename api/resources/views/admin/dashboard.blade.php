@extends('admin.layout')
@section('title', 'Overview')
@section('nav', '1')
@section('top-actions')
  <form method="post" action="/admin/server/tick" class="inline">@csrf<button type="submit">Run the timer now</button></form>
@endsection
@section('content')
@php
  $healthy = $s['queue']['failed'] === 0 && $s['mail_failures']['last_7_days'] === 0
      && $s['last_tick_at'] !== null && $s['database']['used_percent'] < 80;
@endphp
<div class="card" style="display:flex;flex-wrap:wrap;gap:12px 24px;align-items:center;margin-bottom:18px">
  <span class="pill {{ $healthy ? 'ok' : 'warn' }}">{{ $healthy ? 'All systems normal' : 'Something needs a look' }}</span>
  <span class="muted">Timer last ran <b class="mono">{{ $s['last_tick_at'] ?? 'never' }}</b> UTC</span>
  <span class="muted">{{ $s['queue']['failed'] }} failed {{ $s['queue']['failed'] === 1 ? 'job' : 'jobs' }}</span>
  <span class="muted">Database {{ $s['database']['used_percent'] }}% used</span>
  <a href="/admin/health" style="margin-left:auto;font-weight:700">Health & jobs →</a>
</div>

<div class="grid k4">
  @include('admin.partials.kpi', ['label' => 'Live accounts', 'value' => $kpi['accounts'], 'tile' => 'peach',
      'icon' => 'M16 19v-1a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v1M10 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
      'now' => $kpi['signups']['now'], 'before' => $kpi['signups']['before'], 'what' => 'sign-ups'])
  @include('admin.partials.kpi', ['label' => 'Active accounts, 7 days', 'value' => $kpi['active']['now'], 'tile' => 'lime',
      'icon' => 'M3 12h4l3-8 4 16 3-8h4', 'now' => $kpi['active']['now'], 'before' => $kpi['active']['before']])
  @include('admin.partials.kpi', ['label' => 'Check-ins, 7 days', 'value' => $kpi['check_ins']['now'], 'tile' => 'pink',
      'icon' => 'M5 12l4 4 10-10', 'now' => $kpi['check_ins']['now'], 'before' => $kpi['check_ins']['before']])
  @include('admin.partials.kpi', ['label' => 'Notices showing', 'value' => $kpi['notices_live'], 'tile' => 'peach',
      'icon' => 'M4 5h16v11H8l-4 4V5z'])
</div>
<p class="muted" style="margin:10px 2px 0">A week is the last 7 × 24 hours, against the 7 × 24 hours before.</p>

<h2>Last 30 days</h2>
<div class="grid c3">
  @include('admin.partials.bar-chart', ['title' => 'Sign-ups', 'values' => $series['signups'], 'ends' => $series['ends'],
      'noun' => 'sign-ups', 'total' => number_format(array_sum($series['signups']))])
  @include('admin.partials.bar-chart', ['title' => 'Check-ins', 'values' => $series['check_ins'], 'ends' => $series['ends'],
      'noun' => 'check-ins', 'total' => number_format(array_sum($series['check_ins']))])
  @include('admin.partials.bar-chart', ['title' => 'Active accounts per day', 'values' => $series['active'], 'ends' => $series['ends'],
      'noun' => 'active accounts', 'total' => 'peak '.number_format(max($series['active']))])
</div>
<p class="muted" style="margin:10px 2px 0">Each bar is 24 hours counted back from now, in UTC. Counts only: no one's habits are read.</p>

<div class="grid c2" style="margin-top:8px">
  <div>
    <h2>Recent admin actions</h2>
    <div class="table">
      <table>
        <thead><tr><th scope="col">When (UTC)</th><th scope="col">Action</th></tr></thead>
        <tbody>
        @forelse ($actions as $a)
          <tr><td class="mono muted">{{ $a['at'] }}</td><td>{{ $a['action'] }}</td></tr>
        @empty
          <tr><td colspan="2" class="empty">Nothing yet.</td></tr>
        @endforelse
        </tbody>
      </table>
    </div>
    <p><a href="/admin/activity" style="font-weight:700">Full activity log →</a></p>
  </div>
  <div>
    <h2>Quick links</h2>
    <div class="card actions" style="flex-direction:column;align-items:stretch">
      <a class="button secondary" href="/admin/notices">Publish a notice</a>
      <a class="button secondary" href="/admin/accounts?status=suspended">Suspended accounts</a>
      <a class="button secondary" href="/admin/accounts?sort=newest">Newest accounts</a>
    </div>
  </div>
</div>
@endsection
