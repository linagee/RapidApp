package RapidApp::ModuleDispatcher;

use Moose;
use RapidApp::Include 'perlutil';

# either an exceptionStore instance, or the name of a catalyst Model implementing one
has 'exceptionStore'        => ( is => 'rw' );

# Whether to save errors to whichever ExceptionStore is available via whatever configuration
# If this is true and no ExceptionStore is configured, we die
has 'saveErrors'            => ( is => 'rw', isa => 'Bool', default => 0 );

# Whether to record an exception even if "$err->isUserError" is true
has 'saveUserErrors'        => ( is => 'rw', isa => 'Bool', default => 1 );

# Whether to also show the tracking ID to the user for UserErrors (probably only desirable for debugging)
has 'reportIdForUserErrors' => ( is => 'rw', isa => 'Bool', default => 0 );

# Which RapidApp module to dispatch to.  By default, we dispatch to the root.
# If you had multiple ModuleDispatchers, you might choose to dispatch to deeper in the tree.
has 'dispatchTarget'        => ( is => 'rw', isa => 'Str',  default => "/");

=head2 $ctlr->dispatch( $c, @args )

dispatch takes a catalyst instance, and a list of path arguments.  It does some setup work,
and then calls "Controller" on the target module to begin handling the arguments.

dispatch takes care of the special exception handling/saving, and also sets up the
views to display the exceptions.

It also is responsible for cleaning temporary values from the Modules after the request is over.

=cut
our $globalDispatchCount= 0;
sub dispatch {
	my ($self, $c, @args)= @_;
	
	# put the debug flag into the stash, for easy access in templates
	$c->stash->{debug} = $c->debug;
	
	# provide hints for our controllers on what contect type is expected
	$c->stash->{requestContentType}=
		$c->req->header('X-RapidApp-RequestContentType')
		|| $c->req->param('RequestContentType')
		|| '';
	
	# provide a unique identifier for this request instance
	$c->stash->{rapidapp_request_id}= ++$globalDispatchCount;
	
	my $result;
	
	# special die handler to make sure we don't throw plain strings.
	local $SIG{__DIE__}= \&dieConverter;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystInstance => $c,
		  catalystClass => $c->rapidApp->catalystAppClass,
		  log => $c->log,
		},
		sub {
			my $targetModule;
			try {
				# get the root module (or sub-module, if we've been configured that way)
				$targetModule= $c->rapidApp->module($self->dispatchTarget);
				
				# now run the controller
				$result = $targetModule->THIS_MODULE->Controller($c, @args);
				$c->stash->{controllerResult} = $result;
				
				# clear out any temporarily cached attributes generated by this request
				#$targetModule->recursive_clear_per_request_vars;
			}
			catch {
				$result= $self->onException(RapidApp::Error::capture($_, {lateTrace => 1}));
				
				# redundant, but we need to make sure it happens if the request dies
				# we want to leave the other one in the try block so we can catch errors conveniently
				#$targetModule->recursive_clear_per_request_vars if defined $targetModule;
			};
		}
	);
	# if the body was not set, make sure a view was chosen
	defined $c->res->body || defined $c->stash->{current_view} || defined defined $self->c->stash->{current_view_instance}
		or die "No view was selected, and a body was not generated";
	
	return $result;
}

=head2 onException( $c, $RapidApp::Error )

This is called whenever an exception is thrown from the chain of Controller calls.

Default behavior for this routine is to log the exception, dump its debugging info if present,
and render it as either a RapidApp exception (for JSON requests) or as a HTTP-500.

=cut
sub onException {
	my ($self, $err)= @_;
	
	my $c= RapidApp::ScopedGlobals->catalystInstance;
	my $log= RapidApp::ScopedGlobals->log;
	
	$c->stash->{exception}= $err;
	$c->stash->{isUserError}= $err->isUserError;
	
	if ($err->isUserError)  {
		$log->info("User usage error: ".$err->userMessage);
	}
	else {
		$log->error("RapidApp Exception: ".$err->message);
	}
	
	if ($self->saveErrors && (!$err->isUserError || $self->saveUserErrors)) {
		defined $self->exceptionStore or die "saveErrors is set, but no exceptionStore is defined";
		my $store= ref $self->exceptionStore? $self->exceptionStore : $c->model($self->exceptionStore);
		my $refId= $store->saveException($err);
		if (!$err->isUserError || $self->reportIdForUserErrors) {
			$c->stash->{exceptionRefId}= $refId;
		}
	}
	else {
		# not saving error, so just print it
		$log->debug($err->dump);
	}
	
	# on exceptions, we either generate a 503, or a JSON response to the same effect
	if ($c->stash->{requestContentType} eq 'JSON') {
		$c->stash->{current_view}= 'RapidApp::JSON';
	}
	elsif ($err->isUserError) {
		# TODO: change this to an actual view
		length($c->response->body) > 0
			or $c->response->body("Error : " . $err->userMessage);
	}
	else {
		$c->stash->{current_view}= 'RapidApp::HttpStatus';
		$c->res->status(500);
	}
}

sub dieConverter {
	die $_[0] if ref $_[0];
	my $stopTrace= 0;
	die &RapidApp::Error::capture(
		join(' ', @_),
		{ lateTrace => 0, traceArgs => { frame_filter => sub { noCatalystFrameFilter(\$stopTrace, @_) } } }
	);
}

sub noCatalystFrameFilter {
	my ($stopTrace, $params)= @_;
	return 0 if ($$stopTrace);
	$$stopTrace= $params->{caller}->[3] eq 'RapidApp::ModuleDispatcher::dispatch';
	return RapidApp::Error::ignoreSelfFrameFilter($params);
}

1;