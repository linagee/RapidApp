package RapidApp::AppPageViewer;
use strict;
use Moose;
extends 'RapidApp::AppHtml';

use RapidApp::Include qw(sugar perlutil);

# Module allows viewing pages in a tab by file name

use HTML::TokeParser::Simple;
use Text::Markdown 'markdown';
use PPI;
use PPI::HTML;
use Path::Class qw(file);
use Switch qw(switch);

has 'content_dir', is => 'ro', isa => 'Str', required => 1;
has 'parse_title', is => 'ro', isa => 'Bool', default => 1;
has 'alias_dirs', is => 'ro', isa => 'HashRef', default => sub {{}};
has '+accept_subargs', default => 1;

sub _requested_file {
  my $self = shift;
  my $dir = $self->content_dir;
  
  my $file = join('/',$self->local_args) || $self->c->req->params->{file} 
    or die usererr "No file specified", title => "No file specified";
  
  my $path = "$dir/$file";
  
  # Optionally remap if file matches a configured alias_dir:
  my @p = split(/\//,$file);
  my $alias = $self->alias_dirs->{(shift @p)};
  $path = join('/',$alias,@p) if ($alias && scalar(@p > 0));

  $path = $self->c->config->{home} . '/' . $path unless ($path =~ /^\//);
  
  # quick/dirty symlink support:
  $path = readlink($path) if (-l $path);
  $path = $self->c->config->{home} . '/' . $path unless ($path =~ /^\//);
  
  die usererr "$file not found", title => "No such file"
    unless (-f $path);
  
  my @parts = split(/\./,$file);
  
  my $ext = pop @parts;
  return ($path, $file,$ext);
}

sub html {  
  my $self = shift;
  my ($path, $file, $ext) = $self->_requested_file;
  
  $self->apply_extconfig(
    tabTitle => '<span style="color:darkgreen;">' . $file . '</span>',
    tabIconCls => 'icon-document'
  );
  
  my $content;
  
  switch(lc($ext)) {
    case('tt') {
      my $vars = { c => $self->c };
      $content = $self->c->template_render($path,$vars);
    }
    case('pl') {
      return $self->_get_syntax_highlighted_perl($path);
    }
    case('pm') {
      return $self->_get_syntax_highlighted_perl($path);
    }
    case('md') {
      return $self->_render_markdown($path);
    }
    ##
    ## TODO: may support non-templates in the future
    
    else {
      die usererr "Cannot display $file - unknown file extention type '$ext'", 
        title => "Unknown file type"
    }
  }
  
  my $title = $self->parse_title ? $self->_parse_get_title(\$content) : undef;
  $self->apply_extconfig(
    tabTitle => '<span style="color:darkgreen;">' . $title . '</span>',
  ) if ($title);
  
  return $content;

}

sub _parse_get_title {
  my $self = shift;
  my $htmlref = shift;
  
  # quick/simple: return the inner text of the first <title> tag seen
  my $parser = HTML::TokeParser::Simple->new($htmlref);
  while (my $tag = $parser->get_tag) {
    return $parser->get_token->as_is if($tag->is_tag('title')); 
  }

  return undef;
}


sub _render_markdown {
  my $self = shift;
  my $path = shift;
  
  my $markdown = file($path)->slurp;
  my $html = markdown( $markdown );
  
  return join("\n",
    '<div class="ra-doc">',
    $html,
    '</div>'
  );
}

sub _get_syntax_highlighted_perl {
  my $self = shift;
  my $path = shift;
  
  #Module::Runtime::require_module('PPI');
  #Module::Runtime::require_module('PPI::HTML');
  
  # Load your Perl file
  my $Document = PPI::Document->new( $path );
 
  # Create a reusable syntax highlighter
  my $Highlight = PPI::HTML->new( page => 1, line_numbers => 1 );
  
  # Spit out the HTML
  my $content = &_ppi_css .
    '<div class="PPI">' . 
    $Highlight->html( $Document ) .
    '</div>';
  
  return $content;
}

# This is an ugly temp hack:

sub _ppi_css {
  return qq~
<style>

.PPI br {
  display:none;
}

div.PPI {
  background: #eee;
  border: 1px solid #888;
  padding: 4px;
  font-family: monospace;
}
.PPI CODE {
  background: #eee;
  /* border: 1px solid #888;
     padding: 1px; */
}


.PPI span.word {
    color: darkslategray;
}
.PPI span.words {
    color: #999999;
}
.PPI span.transliterate {
    color: #9900FF;
}
.PPI span.substitute {
    color: #9900FF;
}
.PPI span.single {
    color: #999999;
}
.PPI span.regex {
    color: #9900FF;
}
.PPI span.pragma {
    color: #990000;
}
.PPI span.pod {
    color: #008080;
}
.PPI span.operator {
    color: #DD7700;
}
.PPI span.number {
    color: #990000;
}
.PPI span.match {
    color: #9900FF;
}
.PPI span.magic {
    color: #0099FF;
}
.PPI span.literal {
    color: #999999;
}
.PPI span.line_number {
    color: #666666;
}
.PPI span.keyword {
    color: #0000FF;
}
.PPI span.interpolate {
    color: #999999;
}
.PPI span.double {
    color: #999999;
}
.PPI span.core {
    color: #FF0000;
}
.PPI span.comment {
    color: #008080;
}
.PPI span.cast {
    color: #339999;
}
 
 
/* Copyright (c) 2005-2006 ActiveState Software Inc.
 *
 * Styles generated by ActiveState::Scineplex.
 *
 */
 
.SCINEPLEX span.comment {
  color:#ff0000;
  font-style: italic;
}
 
.SCINEPLEX span.default {
}
   
.SCINEPLEX span.keyword {
  color:#0099ff;
}
   
.SCINEPLEX span.here_document {
  color:#009933;
  font-weight: bold;   
}
 
.SCINEPLEX span.number {
  color:#8b0000;
  font-weight: bold;   
}
   
.SCINEPLEX span.operator {
  color:#0000ff;
  font-weight: bold;   
}
   
.SCINEPLEX span.regex {
  color:#c86400;
}
   
.SCINEPLEX span.string {
  color:#009933;
  font-weight: bold;   
}
   
.SCINEPLEX span.variable {
  color:0;
}
  </style>
  ~;
}


1;