@extends('admin.layout')
@section('title', $campaign['subject'])
@section('nav', '1')
@section('content')
@php
  $c = $campaign;
  $done = $c['sent'] + $c['failed'] + $c['skipped'];
  $pct = $c['total'] > 0 ? round($done / $c['total'] * 100) : 0;
@endphp
<p style="margin-top:0"><a href="/admin/emails" style="font-weight:700">← Emails</a></p>
<div class="grid c2">
  <div class="card">
    <div class="actions" style="justify-content:space-between">
      <span class="pill {{ in_array($c['status'], ['sending', 'sent'], true) ? 'ok' : ($c['status'] === 'cancelled' ? 'err' : 'warn') }}">{{ ucfirst($c['status']) }}</span>
      <span class="muted">{{ $c['audience'] }}</span>
    </div>
    @if ($c['status'] === 'scheduled')<p class="muted">Goes out at <b class="mono">{{ $c['scheduled_at'] }}</b> UTC.</p>@endif
    @if ($c['total'] > 0)
      <p style="margin:16px 0 6px"><b class="mono">{{ number_format($c['sent']) }}</b> sent of {{ number_format($c['total']) }} · {{ $c['failed'] }} failed · {{ $c['skipped'] }} skipped</p>
      <div class="meter" role="img" aria-label="{{ $pct }} percent done"><span style="width:{{ $pct }}%"></span></div>
    @endif
    <div class="actions" style="margin-top:16px">
      @if ($c['status'] === 'draft')
        <form method="post" action="/admin/emails/{{ $c['id'] }}/send" class="inline">@csrf<button type="submit">Send now</button></form>
      @endif
      @if (in_array($c['status'], ['draft', 'scheduled', 'sending'], true))
        <form method="post" action="/admin/emails/{{ $c['id'] }}/cancel" class="inline">@csrf<button class="ghost" type="submit">{{ $c['status'] === 'sending' ? 'Stop sending' : 'Cancel' }}</button></form>
      @endif
    </div>
  </div>
  <div class="card" style="background:var(--bg)">
    <p class="muted" style="margin:0 0 6px">Message</p>
    @foreach (array_filter(array_map('trim', preg_split("/\n\s*\n/", $c['body']) ?: [])) as $p)
      <p style="margin:0 0 12px">{!! nl2br(e($p)) !!}</p>
    @endforeach
  </div>
</div>

<h2>Recipients</h2>
<p class="sub">Failed and waiting first. Errors show their kind only.</p>
<div class="table">
  <table>
    <thead><tr><th scope="col">Email</th><th scope="col">Status</th><th scope="col">Error</th><th scope="col">Sent (UTC)</th></tr></thead>
    <tbody>
    @forelse ($deliveries as $d)
      <tr>
        <td>{{ $d['email'] }}</td>
        <td><span class="pill {{ ['sent' => 'ok', 'queued' => 'warn', 'failed' => 'err', 'skipped' => 'warn'][$d['status']] ?? 'warn' }}">{{ ucfirst($d['status']) }}</span></td>
        <td class="muted">{{ $d['error'] ?? '–' }}</td>
        <td class="mono muted">{{ $d['sent_at'] ?? '–' }}</td>
      </tr>
    @empty
      <tr><td colspan="4" class="empty">{{ in_array($c['status'], ['draft', 'scheduled'], true) ? 'Recipients are chosen when sending starts.' : 'No recipients.' }}</td></tr>
    @endforelse
    </tbody>
  </table>
</div>
@endsection
