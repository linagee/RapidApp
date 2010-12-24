package RapidApp::Role::CatalystApplication;

use Moose::Role;
use RapidApp::Include 'perlutil';
use RapidApp::RapidApp;
use RapidApp::ScopedGlobals 'sEnv';
use Scalar::Util 'blessed';

use CatalystX::InjectComponent;

sub rapidApp { (shift)->model("RapidApp"); }

has 'request_id' => ( is => 'ro', default => sub { (shift)->rapidApp->requestCount; } );

around 'setup_components' => sub {
	my ($orig, $app, @args)= @_;
	# At this point, we don't have a catalyst instance yet, just the package name.
	# Catalyst has an amazing number of package methods that masquerade as instance methods later on.
	&flushLog;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => $app, log => $app->log },
		sub {
			$app->$orig(@args);  # standard catalyst setup_components
			$app->setupRapidApp; # our additional components needed for RapidApp
		}
	);
};

sub setupRapidApp {
	my $app= shift;
	my $log= RapidApp::ScopedGlobals->log;
	&flushLog;

	injectUnlessExist('RapidApp::RapidApp', 'RapidApp');
	
	my @names= keys %{ $app->components };
	my @controllers= grep /[^:]+::Controller.*/, @names;
	my $haveRoot= 0;
	foreach my $ctlr (@controllers) {
		if ($ctlr->isa('RapidApp::ModuleDispatcher')) {
			$log->info("RapidApp: Found $ctlr which implements ModuleDispatcher.");
			$haveRoot= 1;
		}
	}
	if (!$haveRoot) {
		$log->info("RapidApp: No Controller extending ModuleDispatcher found, using default");
		injectUnlessExist( 'RapidApp::Controller::DefaultRoot', 'Controller::RapidApp::Root' );
	}
	
	# Enable the DirectLink feature, if asked for
	$app->rapidApp->enableDirectLink
		and injectUnlessExist( 'RapidApp::Controller::DirectLink', 'Controller::RapidApp::DirectLink' );
	
	# for each view, inject it if it doens't exist
	injectUnlessExist( 'Catalyst::View::TT', 'View::RapidApp::TT' );
	injectUnlessExist( 'RapidApp::View::Viewport', 'View::RapidApp::Viewport' );
	injectUnlessExist( 'RapidApp::View::JSON', 'View::RapidApp::JSON' );
	injectUnlessExist( 'RapidApp::View::Web1Render', 'View::RapidApp::Web1Render' );
	injectUnlessExist( 'RapidApp::View::HttpStatus', 'View::RapidApp::HttpStatus' );
};

sub injectUnlessExist {
	my ($actual, $virtual)= @_;
	my $app= RapidApp::ScopedGlobals->catalystClass;
	if (!$app->components->{$virtual}) {
		sEnv->log->debug("RapidApp: Installing virtual $virtual");
		CatalystX::InjectComponent->inject( into => $app, component => $actual, as => $virtual );
	}
}

after 'setup_finalize' => sub {
	my $app= shift;
	&flushLog;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => $app, log => $app->log },
		sub { $app->rapidApp->_setup_finalize }
	);
};

# Make the scoped-globals catalystClass and log available throughout the application during request processing
# Called once, per worker thread, in class-context.
around 'run' => sub {
	my ($orig, $app, @args)= @_;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => $app, log => $app->log },
		$orig, $app, @args
	);
};

# called once per request, in class-context
before 'handle_request' => sub {
	my ($app, @arguments)= @_;
	$app->rapidApp->incRequestCount;
};

# called once per request, to dispatch the request on a newly constructed $c object
around 'dispatch' => sub {
	my ($orig, $c, @args)= @_;
	$c->stash->{onrequest_time_elapsed}= 0;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystInstance => $c, log => $c->log },
		$orig, $c, @args
	);
};

# called after the response is sent to the client, in object-context
after 'log_response' => sub {
	my $c= shift;
	$c->rapidApp->cleanupAfterRequest($c);
};

sub flushLog {
	my $log= RapidApp::ScopedGlobals->get("log");
	if (!defined $log) {
		my $app= RapidApp::ScopedGlobals->get("catalystClass");
		$log= $app->log if defined $app;
	}
	defined $log or return;
	if (my $coderef = $log->can('_flush')){
		$log->$coderef();
	}
}

1;
