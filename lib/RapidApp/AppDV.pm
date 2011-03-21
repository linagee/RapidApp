package RapidApp::AppDV;
# Editable DataView class

use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';

use RapidApp::Include qw(sugar perlutil);

use Template;
use RapidApp::AppDV::TTController;

has 'TTController'  => (
	is => 'ro',
	isa => 'RapidApp::AppDV::TTController',
	lazy => 1,
	default => sub {
		my $self = shift;
		return RapidApp::AppDV::TTController->new( AppDV => $self );
	}
);

has 'tt_include_path' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
		return $self->app->config->{RapidApp}->{rapidapp_root};
	}
);

has 'tt_file' => ( is => 'ro', isa => 'Str', required => 1 );


has 'submodule_config_override' => (
	is        => 'ro',
	isa       => 'HashRef[HashRef]',
	default   => sub { {} }
);

has '+DataStore_build_params' => ( default => sub {{
	store_autoLoad => \1
}});

sub BUILD {
	my $self = shift;

	$self->apply_extconfig(
		id					=> $self->instance_id,
		xtype				=> 'appdv',
		autoHeight		=> \1,
		multiSelect		=> \1,
		simpleSelect	=> \1,
		overClass		=> 'record-over',
		items => []
		#tpl				=> $self->xtemplate
	);
	
	
	#$self->add_listener( afterrender	=> 'Ext.ux.RapidApp.AppDV.afterrender_handler' );
	#$self->add_listener(	click 		=> 'Ext.ux.RapidApp.AppDV.click_handler' );
	
	# FIXME: call this once instead of on every request:
	$self->add_ONREQUEST_calls('load_xtemplate');

}

sub load_xtemplate {
	my $self = shift;
	$self->apply_extconfig( tpl => $self->xtemplate );
	$self->apply_extconfig( FieldCmp_cnf => $self->FieldCmp );
	$self->apply_extconfig( items => [ values %{ $self->DVitems } ] );
}




sub xtemplate {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.XTemplate',
		parm => [ $self->xtemplate_cnf ]
	);
}


has 'DVitems' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
has 'FieldCmp' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

has 'xtemplate_cnf' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
		
		my $html_out = '';
		
		my $Template = Template->new({ INCLUDE_PATH => $self->tt_include_path });
		$Template->process($self->tt_file,{ r => $self->TTController },\$html_out)
			or die $Template->error;
		
		return $html_out;
		}
);

# Dummy read_records:
sub read_records {
	my $self = shift;
	
	return {
		results => 1,
		rows => [{ $self->record_pk => 1 }]
	};
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;