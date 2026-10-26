@extends('admin.layout')
@section('title', 'Accounts')
@section('nav', '1')
@section('content')
<h1>Accounts</h1>
<form method="get" action="/admin/accounts" class="card" role="search">
  <label for="q">Search by email or name</label>
  <input id="q" name="q" value="{{ $q }}">
  <p><button type="submit">Search</button></p>
</form>
<table>
  <thead><tr><th scope="col">Email</th><th scope="col">Name</th><th scope="col">Joined (UTC)</th><th scope="col">Status</th><th scope="col">Devices</th></tr></thead>
  <tbody>
  @forelse ($rows as $r)
    <tr>
      <td><a href="/admin/accounts/{{ $r['id'] }}">{{ $r['email'] }}</a></td>
      <td>{{ $r['name'] }}</td>
      <td class="muted">{{ $r['joined'] }}</td>
      <td><span class="pill {{ $r['status'] === 'deletion pending' ? 'deletion' : $r['status'] }}">{{ $r['status'] }}</span></td>
      <td>{{ $r['devices'] }}</td>
    </tr>
  @empty
    <tr><td colspan="5" class="muted">No accounts match.</td></tr>
  @endforelse
  </tbody>
</table>
<p>
  @if ($page > 1)<a href="/admin/accounts?q={{ urlencode($q) }}&page={{ $page - 1 }}">Previous</a>@endif
  @if ($more)<a href="/admin/accounts?q={{ urlencode($q) }}&page={{ $page + 1 }}" style="margin-left:16px">Next</a>@endif
</p>
@endsection
