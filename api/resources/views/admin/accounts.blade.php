@extends('admin.layout')
@section('title', 'Accounts')
@section('nav', '1')
@section('content')
@php
  $link = fn (array $over) => '/admin/accounts?'.http_build_query(array_filter([...['q' => $q, 'status' => $status, 'sort' => $sort], ...$over], fn ($v) => $v !== '' && $v !== null));
  $labels = ['all' => 'All', 'active' => 'Active', 'suspended' => 'Suspended', 'deletion' => 'Deletion pending'];
@endphp
<nav class="chips" aria-label="Filter by status">
  @foreach ($labels as $key => $label)
    <a href="{{ $link(['status' => $key, 'page' => null]) }}" @if($status === $key) aria-current="true" @endif>{{ $label }} <span class="count">{{ number_format($counts[$key]) }}</span></a>
  @endforeach
</nav>

<form method="get" action="/admin/accounts" class="filters" role="search">
  <input type="hidden" name="status" value="{{ $status }}">
  <div style="flex:3"><label for="q">Search by email or name</label><input id="q" name="q" value="{{ $q }}"></div>
  <div><label for="sort">Sort</label>
    <select id="sort" name="sort">
      @foreach (['newest' => 'Newest first', 'oldest' => 'Oldest first', 'last_active' => 'Last active', 'email' => 'Email A–Z'] as $key => $label)
        <option value="{{ $key }}" @selected($sort === $key)>{{ $label }}</option>
      @endforeach
    </select>
  </div>
  <div style="flex:none"><button type="submit">Apply</button></div>
</form>

<div class="table">
  <table>
    <thead><tr><th scope="col">Account</th><th scope="col">Status</th><th scope="col">Joined (UTC)</th><th scope="col">Last active (UTC)</th><th scope="col" class="num">Devices</th></tr></thead>
    <tbody>
    @forelse ($rows as $r)
      <tr>
        <td><a href="/admin/accounts/{{ $r['id'] }}" style="font-weight:700">{{ $r['email'] }}</a><div class="muted">{{ $r['name'] }}</div></td>
        <td><span class="pill {{ $r['status'] === 'deletion pending' ? 'deletion' : $r['status'] }}">{{ $r['status'] }}</span></td>
        <td class="mono muted">{{ substr($r['joined'], 0, 10) }}</td>
        <td class="mono muted">{{ $r['last_active'] === null ? '–' : str_replace(['T', 'Z'], [' ', ''], substr($r['last_active'], 0, 16)) }}</td>
        <td class="num">{{ $r['devices'] }}</td>
      </tr>
    @empty
      <tr><td colspan="5" class="empty">No accounts match.</td></tr>
    @endforelse
    </tbody>
  </table>
</div>
<div class="pager">
  @if ($page > 1)<a href="{{ $link(['page' => $page - 1]) }}">← Previous</a>@endif
  @if ($more)<a href="{{ $link(['page' => $page + 1]) }}">Next →</a>@endif
</div>
@endsection
