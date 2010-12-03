package RapidApp::UserError;

use Moose;
extends 'RapidApp::Error';

around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	my $params= ref $args[0] eq 'HASH'? $args[0]
		: (scalar(@args) == 1? { userMessage => $args[0] } : { @args } );
	
	return $class->$orig($params);
}

sub userMessage {
	my $self= shift;
	my $actual= $self->SUPER::userMessage(@_);
	return $actual || $self->message;
}

sub isUserError { 1 }

sub as_string {
	return (shift)->userMessage;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;