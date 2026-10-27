@extends('admin.layout')
@section('title', 'Activity log')
@section('nav', '1')
@section('content')
@php
  $link = fn (int $p) => '/admin/activity?'.http_build_query(array_filter([...$filters, 'page' => $p], fn ($v) => $v !== ''));
@endphp
<p class="sub" style="margin-top:0">Every admin sign-in and action, newest first. Subjects are ids: an account, a notice or a job.</p>
<form method="get" action="/admin/activity" class="filters">
  <div><label for="action">Action</label>
    <select id="action" name="action">
      <option value="">All actions</option>
      @foreach ($actions as $act)
        <option value="{{ $act }}" @selected($filters['action'] === $act)>{{ $act }}</option>
      @endforeach
    </select>
  </div>
  <div><label for="from">From (UTC date)</label><input id="from" name="from" type="date" value="{{ $filters['from'] }}"></div>
  <div><label for="to">To (UTC date)</label><input id="to" name="to" type="date" value="{{ $filters['to'] }}"></div>
  <div style="flex:none"><button type="submit">Filter</button></div>
</form>
<div class="table">
  <table>
    <thead><tr><th scope="col">When (UTC)</th><th scope="col">Action</th><th scope="col">Subject</th><th scope="col">Detail</th></tr></thead>
    <tbody>
    @forelse ($rows as $r)
      <tr>
        <td class="mono muted">{{ $r['at'] }}</td>
        <td><b>{{ $r['action'] }}</b></td>
        <td class="mono muted">@if ($r['subject'] !== null && str_starts_with($r['action'], 'account.'))<a href="/admin/accounts/{{ $r['subject'] }}">{{ $r['subject'] }}</a>@else{{ $r['subject'] ?? '–' }}@endif</td>
        <td class="muted">{{ $r['detail'] }}</td>
      </tr>
    @empty
      <tr><td colspan="4" class="empty">Nothing matches.</td></tr>
    @endforelse
    </tbody>
  </table>
</div>
<div class="pager">
  @if ($page > 1)<a href="{{ $link($page - 1) }}">← Newer</a>@endif
  @if ($more)<a href="{{ $link($page + 1) }}">Older →</a>@endif
</div>
@endsection
