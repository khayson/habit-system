@extends('emails.page')
@section('title', 'Emails on')
@section('content')
  <h1>Announcement emails are on</h1>
  <p>You will hear from us about important changes to Habit System: updates, changes to the terms, planned downtime and security.</p>
  <p><a href="{{ $stopUrl }}">Stop them again</a></p>
@endsection
