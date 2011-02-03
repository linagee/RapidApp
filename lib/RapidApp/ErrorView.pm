package RapidApp::ErrorView;

use Moose;
extends 'RapidApp::AppStoreForm2';

use RapidApp::Include qw(perlutil sugar);

use RapidApp::DbicExceptionStore;

# make sure the as_html method gets loaded into StackTrace, which might get deserialized
use Devel::StackTrace;
use Devel::StackTrace::WithLexicals;
use Devel::StackTrace::AsHTML;

has 'errorReportStore' => ( is => 'rw', isa => 'Str|RapidApp::Role::ExceptionStore' );
has 'useParentExceptionStore' => ( is => 'rw', isa => 'Bool', lazy => 1, default => 0 );

sub resolveErrorReportStore {
	my $self= shift;
	
	my $store= $self->useParentExceptionStore? $self->parent_module->resolveErrorReportStore : undef;
	$store ||= $self->errorReportStore;
	$store ||= $self->app->rapidApp->resolveErrorReportStore;
	
	defined $store or die "No ErrorReportStore configured";
	return (ref $store? $store : $self->app->model($store));
}

my $read_only_style= {
	'background-color'	=> 'transparent',
	'border-color'		=> 'transparent',
	'background-image'	=> 'none',
	
	# the normal text field has padding-top: 2px which makes the text sit towards
	# the bottom of the field. We set top and bot here to move one of the px to the
	# bottom so the text will be vertically centered but take up the same vertical
	# size as a normal text field:
	'padding-top'		=> '1px',
	'padding-bottom'	=> '1px'
};

override_defaults(
	auto_web1 => 1,
);

sub BUILD {
	my $self= shift;
	
	# Register ourselves with RapidApp if no other has already been registered
	# This affects any hyperlinks to exception reports generated by RapidApp modules.
	defined $self->app->rapidApp->errorViewPath
		or $self->app->rapidApp->errorViewPath($self->module_path);
	
	$self->apply_actions(
		view => 'view',
		trace => 'trace',
		gen_die => 'gen_die',
		gen_error => 'gen_error',
		gen_usererror => 'gen_usererror',
	);
	
	$self->apply_extconfig(
		labelAlign	=> 'left',
		bodyStyle	=> 'padding:25px 25px 15px 15px;',
		labelWidth 	=> 130,
		defaults => {
			xtype 		=> 'displayfield',
			width			=> 'auto',
			#style => $read_only_style
		}
	);
	
	$self->add_formpanel_items(
		{ name => 'id',        fieldLabel => 'ID' },
		{ name => 'dateTime',  fieldLabel => 'Date' },
		{ name => 'exception', fieldLabel => 'Error' },
		{ name => 'traces',    fieldLabel => 'Stack' },
		{ name => 'debugInfo', fieldLabel => 'Info' },
	);
	
	$self->DataStore->apply_flags(
		can_read	=> 1,
		can_update	=> 0,
		can_create	=> 0,
	);
}

sub getErrorReport {
	my ($self, $id)= @_;
	# Generating an exception while trying to view exceptions wouldn't be too useful
	#   so we trap and display exceptions specially in this module.
	my $report;
	try {
		defined $id or die "No ID specified";
		
		my $store= $self->resolveErrorReportStore;
		$report= $store->loadErrorReport($id);
	}
	catch {
		$report= RapidApp::ErrorReport->new(
			id => $id,
			exception => '',
			traces => [],
			debugInfo => { 'failed to load!' => $_ }
		);
	};
	return $report;
}

our $RENDERCXT= undef;
sub web1_render_extcfg {
	my ($self, $renderCxt, $extCfg)= @_;
	$renderCxt->incCSS('/static/rapidapp/css/data2html.css');
	$self->SUPER::web1_render_extcfg($renderCxt, $extCfg);
}

sub read_records {
	my ($self, $params)= @_;
	my $id = $params->{id};
	defined $id or die "cannot lookup row without id";
	my $errReport= $self->getErrorReport($id);
	
	my $htmlRenderCxt= RapidApp::Web1RenderContext->new();
	
	$htmlRenderCxt->render($errReport->exception);
	my $exceptionStr= $htmlRenderCxt->getBody;
	
	my $idx= 0;
	my $traceStr= join "<br/><hr width='70%' /><br/>\n\n\n", map {
		'<div><a href="'.$self->suburl('trace').'?id='.$id.'&trace_idx='.($idx++).'" target="_blank">View as HTML in new window</a></div>'
		.$self->renderTrace_brief($_)
		} @{$errReport->traces || []};
	
	$htmlRenderCxt->body_fragments([]);
	$htmlRenderCxt->data2html($errReport->debugInfo);
	my $infoStr= $htmlRenderCxt->getBody;
	
	my $row= {
		id => $id,
		dateTime => $errReport->dateTime->ymd .' '. $errReport->dateTime->hms,
		exception => $exceptionStr,
		traces => $traceStr,
		debugInfo => $infoStr,
	};
	return {
		results	=> 1,
		rows	=> [ $row ],
	};
}

=pod
	my $traceStr;
	for my $frame ($err->trace->frames) {
		my $fname= $frame->filename;
		$fname =~ s|.*?/lib/perl[^/]+/([^A-Z][^/]*/)*||;
		$fname =~ s|.*?/lib/||;
		my $loc= sprintf('<font color="blue">%s</font> line <font color="blue">%d</font>', $fname, $frame->line);
		my $call= sprintf('<b>%s</b>( %s )', $frame->subroutine, join (', ',$frame->args) );
		$call =~ s/([^ ]+)=HASH[^ ,]+/\\%$1/g;
		$traceStr .= '<div class="trace" style="padding: .3em 0 1em 0">'.$loc.' : <br/><span style="padding:1px 2em"> </span>'.$call.'</div>';
	}
=cut
sub renderTrace_brief {
	my ($self, $trace)= @_;
	my $ret= "<div style='margin:0.2em 1em 2em 1em; font-size:10pt'>\n";
	my $max= 25;
	for my $frame ($trace->frames) {
		if (!--$max) {
			$ret .= '<div> ... </div>';
			last;
		}
		my $fname= $frame->filename;
		$fname =~ s|.*?/lib/perl[^/]+/([^A-Z][^/]*/)*||;
		$fname =~ s|.*?/lib/||;
		my $loc= sprintf('<font color="blue">%s</font> line <font color="blue">%d</font>', $fname, $frame->line);
		
		my $call= sprintf('<b>%s</b>', $frame->subroutine);
		my $args= '<span style="font-size: 8pt">'.join('<br />', map { briefString($_) } $frame->args).'</span>';
		#$call =~ s/([^ ]+)=HASH[^ ,]+/\\%$1/g;
		
		$ret .= "<div> $loc <table style='padding-left:2em'><tr><td valign='top'>$call".'&nbsp;'."(</td><td> $args </td></tr></table></div>\n";
	}
	$ret .= "\n</div>";
	return $ret;
}

sub _hashToStr {
	my $hash= shift;
	return '{ '.(join ', ', map { $_.'="'.$hash->{$_}.'"' } sort keys %$hash).' }';
};
sub _trimAtLen {
	my ($len, $str)= @_;
	$str =~ s/ /&nbsp;/g;
	length($str) < $len? $str : substr($str, 0, $len).'...';
}
sub briefString {
	my $value= shift;
	!defined $value and return '<undef>';
	!ref $value and return _trimAtLen(200, $value);
	ref $value eq 'HASH' and return _trimAtLen(70, _hashToStr($value));
	ref $value eq 'ARRAY' and return '['._trimAtLen(70, join(', ', @$value)).']';
	return _trimAtLen(70, ''.$value);
}

sub trace {
	my $self= shift;
	my $c= $self->c;
	my $id= $c->req->params->{id};
	defined $id	or die "ErrorReport id is required";
	my $traceIdx= $c->req->params->{trace_idx};
	defined $traceIdx or die "Trace index is required";
	
	my $errReport= $self->getErrorReport($id);
	my $trace= $errReport->traces->[$traceIdx];
	
	$c->res->content_type("text/html; charset=UTF-8");
	$c->res->body($trace->as_html);
	$c->res->status(200);
}

sub gen_die {
	die "Deliberately generating an exception";
}

sub gen_error {
	die RapidApp::Error->new("Generating an exception using the RapidApp::Error class");
}

sub gen_usererror {
	die usererr "PEBKAC";
}

=pod
sub extconfig {
	my $self= shift;
	my $id= $self->c->req->params->{id};
	defined $id or die "No ID specified";
	
	my $err= $self->getExceptionObj($id);
	
	return {
		xtype => 'box',
		html => $self->c->view("RapidApp::TT")->render($self->c, 'templates/rapidapp/exception.tt', { ex => $err })
	};
}

sub web1config {
	my $self= shift;
	my $extCfg= $self->extconfig;
	return $extCfg->{html};
}

=cut
1;
