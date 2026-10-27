@extends('emails.page')
@section('title', 'Emails stopped')
@section('content')
  <h1>You won't get announcement emails</h1>
  <p>We have stopped service announcements for your Habit System account. Password reset codes still arrive when you ask for one.</p>
  <p><a class="button" href="{{ $startUrl }}">Turn them back on</a></p>
@endsection
