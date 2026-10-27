@extends('admin.layout')
@section('title', 'Emails')
@section('nav', '1')
@section('top-actions')
  <a class="button" href="/admin/emails/new">New announcement</a>
@endsection
@section('content')
<div class="grid k4">
  <div class="kpi">
    <div class="label">Sent, last 24 hours</div>
    <div class="value mono">{{ number_format($sentToday) }} <span class="muted" style="font-size:16px">of {{ number_format($dailyLimit) }}</span></div>
    <div class="meter" role="img" aria-label="{{ $sentToday }} of {{ $dailyLimit }} sent in the last 24 hours"><span style="width:{{ min(100, $dailyLimit > 0 ? $sentToday / $dailyLimit * 100 : 0) }}%"></span></div>
    <div class="delta">A campaign over the cap carries on by itself; the rest is kept for reset codes.</div>
  </div>
  <div class="kpi">
    <div class="label">Stopped these emails</div>
    <div class="value mono">{{ number_format($stopped) }}</div>
    <div class="delta">They are left out of every announcement.</div>
  </div>
</div>
<p class="muted" style="margin:10px 2px 0">Service announcements only: updates, changes to the terms, planned downtime, security. Not marketing.</p>

<h2>Announcements</h2>
<div class="table">
  <table>
    <thead><tr><th scope="col">Subject</th><th scope="col">For</th><th scope="col">Status</th><th scope="col" class="num">Sent</th><th scope="col">Created (UTC)</th></tr></thead>
    <tbody>
    @forelse ($campaigns as $c)
      @php $tone = ['draft' => 'warn', 'scheduled' => 'warn', 'sending' => 'ok', 'sent' => 'ok', 'cancelled' => 'err'][$c['status']] ?? 'warn'; @endphp
      <tr>
        <td><a href="/admin/emails/{{ $c['id'] }}" style="font-weight:700">{{ $c['subject'] }}</a></td>
        <td class="muted">{{ $c['audience'] }}</td>
        <td><span class="pill {{ $tone }}">{{ ucfirst($c['status']) }}</span>@if($c['status'] === 'scheduled' && $c['scheduled_at'])<div class="muted mono">{{ $c['scheduled_at'] }}</div>@endif</td>
        <td class="num">{{ number_format($c['sent']) }}@if($c['total'] > 0) <span class="muted">/ {{ number_format($c['total']) }}</span>@endif</td>
        <td class="mono muted">{{ $c['created_at'] }}</td>
      </tr>
    @empty
      <tr><td colspan="5" class="empty">No announcements yet. <a href="/admin/emails/new">Write the first one</a>.</td></tr>
    @endforelse
    </tbody>
  </table>
</div>
@endsection
