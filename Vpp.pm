############################################################
#
# $Header: /mnt/barrayar/d06/home/domi/Tools/perlDev/Text_Vpp/RCS/Vpp.pm,v 1.15 1998/08/11 13:18:47 domi Exp $
#
# $Source: /mnt/barrayar/d06/home/domi/Tools/perlDev/Text_Vpp/RCS/Vpp.pm,v $
# $Revision: 1.15 $
# $Locker:  $
# 
############################################################

package Text::Vpp;

require 5.005;
use strict;
use vars qw($VERSION);
use FileHandle ;
use Carp ;

use AutoLoader qw/AUTOLOAD/ ;

$VERSION = '1.01';

sub new
  {
    my $type = shift ;
    
    my $self     = {} ;
    my $file     = shift ;
    my $ref      = shift ;
    my $action   = shift ;
    my $comment  = shift ;
    my $prefix   = shift;
    my $backslash= shift;
    
    if (defined $ref && (ref($ref) eq "HASH"))
      {
        $self->{var} = $ref ;
      }
    
    $self->{action}    = defined $action    ? $action    : '@' ;
    $self->{comment}   = defined $comment   ? $comment   : '#' ;
    $prefix= '$'  unless defined($prefix); #' ; 
    $self->{prefix}    = $prefix ;
    $self->{VarPat}    = qr/\Q$prefix\E({?)(\w+)\b(}?)/;
    $self->{backslash} = defined $backslash ? $backslash :  1  ;
    
    $self->{fileDesc} = new FileHandle ;

    $self->{name} = $file ;
    $self->{fileDesc}->open($file) || die "can't open $file \n";
	
    bless $self,$type ;
  }


sub myEval 
  {
    my $self = shift ;
    my $expression = shift ;
    
    # transform each $xxx into $self->{var}{$xxx}
    # this allows for the creation of new variables
    # one may use the construction ${\w} to protect against this
    $expression =~ s[\$(\w+)\b] [\$self->{var}{$1}]g ;
	
    my $return = eval($expression) ;
	
    if ($@ ne "") {
      die "Error in eval : $@ \n",
      "line : $expression \nfile: $self->{name} line $.\n";
    }
    return ($return);
  }

sub ReplaceVars
  {
    my $self = shift ;
    $_[0] =~ s[\$({?)(\w+)\b(}?)]
      [if (defined($self->{var}{$2}))
       { "\$self->{var}{$2}" . ( !$1 ? $3 : '' ); }
       else {"\$$1$2$3";}
      ]ge
    }

sub myExpression
  {
    my $self = shift ;
    my $expression = shift ;
	
    $self->ReplaceVars($expression);
	
    my $return = eval($expression) ;
	
    if ($@ ne "") {
      die "Error in eval : $@ \n",
      "line : $expression \nfile: $self->{name} line $.\n";
    }
    return ($return);
  }


sub substitute
  {
    #return array ref made of new file
    my $self = shift ;

    my $fileOut = shift ;

    $self->{errorText} = [] ;
    $self->{error} = 0;

    $self->{fileDesc}->seek(0,0);
    $self->{IF_Level}= 0;  $self->{FOR_Level}= 0;

    my $res = $self->processBlock(1,1,0) ;

    if (defined $fileOut)
      {
        print "writing $fileOut\n";
        my $FileOut = $fileOut;
        $FileOut= ">$fileOut"  unless $fileOut =~/^>/;
        unless( open(SUBSTITUTEOUT,$FileOut))
          {
            $self->snitch("cannot open $fileOut") ;
            return 0 ;
          }
        print SUBSTITUTEOUT join("\n",@$res) ,"\n" ;
        close(SUBSTITUTEOUT) ;
      }
    else
      {
        $self->{result} = $res ;
      }
    
    return  (not $self->{error} ) ;
  }

sub getText
  {
    my $self = shift ;
    return $self->{result} ;
  }

sub getErrors
  {
    my $self = shift  ;
    return $self->{errorText} ;
  }

sub processBlock 
  {
    # three parameters :
    # GlobExpand : false if nothing should be expanded
    # Expand : true if the calling ifdef is true
    my ($self,$globExpand,$expand,$EnterLoop)=@_ ;
    my $action    = $self->{action} ;
    my $comment   = $self->{comment};
    my $prefix    = $self->{prefix} ;
    my $backslash = $self->{backslash};
    my $VarPat    = $self->{VarPat};
    
    my $out = [] ;
    
    # Done is used to evaluate the elsif
    my ($done) = $expand ;
    
    # Stage is used for syntax check
    my ($stage) = ($self->{IF_Level} == 0 || $EnterLoop) ? 0 : 1 ;
    
    my ($line,$keep,$SubsIt) ;
    local $/ = "\n";            # revert to standard line ending
    my $ifPat      = $action."if" ;
    my $elsifPat   = $action."elsif" ;
    my $elsePat    = $action."else" ;
    my $endifPat   = $action."endif" ;
    my $includePat = $action."include" ;
    my $evalPat    = $action."eval" ;
    my $subsPat    = $action.$action;
    my $foreachPat = $action."foreach";
    my $endforPat  = $action."endfor";
    
    while (defined($line = $self->{fileDesc}->getline) ) 
      {
        chomp($line);
        #skip commented lines
        next if (defined $comment and $line =~ /^\s*\Q$comment\E/);
        
        # get following line if the line is ended by \
        # (followed by tab or whitespaces)
        if ($backslash == 1 and $line =~ s/\\\s*$//) 
          {
            $keep .= $line ;
            next ;
          }
        
        my $lineIn;
        if (defined $keep)
          {
            $lineIn = $keep.$line ;
            undef $keep ;
          } 
        else
          {
            $lineIn = $line ;
          }
        
        study $lineIn;
        if ($lineIn =~ s/^\s*\Q$ifPat\E\s*//i) 
          {
            # process the lines after the IF,
            # don't evaluate the boolean expression if  ! $expand
            my ($expandLoc) = $expand && $self->myExpression($lineIn) ;
            my $Current_IF_Level = $self->{IF_Level}++;
            push @$out, @{$self->processBlock($expand , $expandLoc, 0)} ;
            if ( $self->{IF_Level} != $Current_IF_Level )
              { $self->snitch("illegal nesting of FOREACH and IF"); return [];}
          }
        elsif ($lineIn =~ s/^\s*\Q$elsifPat\E\s*//i) 
          {
            # process the lines after the ELSIF, done is set if the block
            # is expanded
            $self->snitch("unexpected elsif") 
              unless ($stage == 1 or $stage ==2) ;

            $stage = 2 ;
            if ( $done )        # if-condition was true
              { $expand= 0; }   # now we are in the else
            else
              {                 # if-condition was false, so here we have a new chance
                $expand = $self->myExpression($lineIn) ;
                $done = $expand ;
              }
          }
        elsif ($lineIn =~ /^\s*\Q$elsePat\E/i) 
          {
            if ($stage == 0 || $stage == 3 ) 
              {
                $self->snitch("unexpected else");
              }
            $stage = 3 ;
            $expand = !$done ;
          } 
        elsif ($lineIn =~ /^\s*\Q$endifPat\E/i) 
          {
            if ($stage == 0) {$self->snitch("unexpected endif");}
            $self->{IF_Level}--;
            return $out ;
          }
        elsif ($lineIn =~ s/^\s*\Q$foreachPat\E\s*//i)
          { 
            my ($emptyLoop,$Current_FOR_Level) = (1,$self->{FOR_Level});
            if ( $expand && $globExpand )
              { 
                my $LoopExpr = $lineIn;
                $LoopExpr =~ s/^\s*my\s//;  # remove my if there
                my $LoopVar= $1 if $LoopExpr =~ s/\$(\w+)//;
                       
                $self->ReplaceVars($LoopExpr);
                my @LoopList= eval $LoopExpr;
                if ( $@ ) 
                  { 
                    die "Error in FOREACH-List-Expression: $@\n",
                    "line : $lineIn\nfile: $self->{name} line $.\n";
                  }
                my $Start_of_Loop= $self->{fileDesc}->tell;
 
                foreach my $LpVar (@LoopList)
                  { 
                    $self->{var}{$LoopVar}= $LpVar;
                    $self->{FOR_Level}++;
                    $self->{fileDesc}->seek($Start_of_Loop,0) 
                      unless $emptyLoop; # 1st time
                    $emptyLoop= 0;
                    push @$out, @{$self->processBlock($globExpand,$expand,1)} ;
                    if ( $Current_FOR_Level != $self->{FOR_Level} )
                      { 
                        $self->snitch("illegal nesting for IF and FOREACH"); 
                        return []; 
                      }
                  }
              }
            
            if ($emptyLoop)     # loop has been never executed
              { 
                $self->{FOR_Level}++;
                $self->processBlock(0,$expand,1); # process but don't expand
                if ( $Current_FOR_Level != $self->{FOR_Level} )
                  { 
                    $self->snitch("illegal nesting for IF and FOREACH"); 
                    return []; 
                  }
              }
          }
        elsif ($lineIn =~ /^\s*\Q$endforPat\E/i)
          {  
            $self->{FOR_Level}--; 
            return $out;
          }
        elsif ($lineIn =~ /^\s*\Q$includePat\E/i)
          {
            # look like we've got a new file to slurp
            $lineIn =~ s/^\s*\Q$includePat\E\s+//i ;
            my $newFileName = $self->myEval($lineIn);
            my $newFile =  Text::Vpp-> new ($newFileName, $self->{var},
                                            $action,$comment,$prefix,$backslash) ;
            if ($newFile->substitute())
              {
                my $res = $newFile->getText() ;
                push @$out, @$res ;
              } 
            else
              {
                # an error occured
                push @{$self->{errorText}}, @{$newFile->getErrors()} ;
                $self->{error} = 1;
                return $out  ;
              }
            undef $newFile ;
          }
        elsif ($lineIn =~ s/^\s*\Q$evalPat\E//i)
          { 
            if ($expand && $globExpand) { $self->myEval($lineIn); }
          }
        elsif ( $SubsIt=($lineIn =~ /\Q$subsPat\E/)  ||  $lineIn !~ /\Q$action\E/ )
          {
            # process the line
            if ($expand && $globExpand) 
              { 
                if ( $SubsIt )  # eval substitution parts
                  { 
                    $lineIn =~ s/\Q$subsPat\E(.*?)\Q$subsPat\E/$self->myExpression($1)/ge;
                  }
                
                # substitute variables 
                $lineIn =~ s[$VarPat]
                  [ if (defined($self->{var}{$2})) 
                    { $self->{var}{$2} . ( !$1 ? $3 : '' ) ;}
                    else    {"$prefix$1$2$3"  ;}
                  ]ge ;
                push @$out, $lineIn ;
              }
          }
        else
          {
            $self->snitch("Unknown command :$lineIn") ;
          }
      }
	
    if ($self->{IF_Level} > 0 ) 
      {
        $self->snitch("Finished inside a conditionnal block");
      }
    elsif ( $self->{FOR_Level} > 0 ) 
      {
        $self->snitch("Finished inside a FOREACH block");
      }

    return $out ;
  }

1;

__END__


# Preloaded methods go here.

=head1 NAME

Text::Vpp - Perl extension for a versatile text pre-processor

=head1 SYNOPSIS

 use Text::Vpp ;

 $fin = Text::Vpp-> new('input_file_name') ;

 $fin->setVar('one_variable_name' => 'value_one', 
              'another_variable_name' => 'value_two') ;

 $res = $fin -> substitute ; # or directly $fin -> substitute('file_out') 

 die "Vpp error ",$fin->getErrors,"\n" unless $res ;

 $fout = $fin->getText ;

 print "Result is : \n\n",join("\n",@$fout) ,"\n";

=head1 DESCRIPTION

This class enables to preprocess a file a bit like cpp. 

First you create a Vpp object passing the name of the file to process, then
you call setvar() to set the variables you need.

Finally you call substitute on the Vpp object. 

=head1 NON-DESCRIPTION

Note that it's not
designed to replace the well known cpp. Note also that if you think of
using it to pre-process a perl script, you're likely to shoot yourself
in the foot. Perl has a lot of built-in mechanisms so that a pre-processor
is not necessary.

=head1 INPUT FILE SYNTAX

=head2 Comments

All lines beginning with '#' are skipped. (May be changed with 
setCommentChar())

When setActionChar() is called with '#' as a parameter, Vpp doesn't 
skip lines beginning with '#'. In this case, there's no comment possible.

=head2 in-line eval

Lines beginning with '@EVAL' (@ being pompously named the 'action
char') are evaluated as small perl script.  If a line contains
(multiple) @@ Perl-Expression @@ constructs these are replaced by the
value of that Perl-Expression.  You can access all (non-lexically
scoped) variables and subroutines from any Perl package if you use
fully qualified names, i.e. for a subroutine I<foo> in package I<main>
use I<::foo> or I<main::foo>

=head2 Multi-line input

Lines ending with \ are concatenated with the following line.

=head2 Variables substitution

You can specify variables in your text beginning with $ (like in perl,
but may be changed with setPrefixChar() ).  These variables can be set
either by the setVar() method or by the 'eval' capability of Vpp (See
below).

=head2 Setting variables

Lines beginning by @ are 'evaled' using variables defined by setVar().
You can use only scalar variables. This way, you can also define
variables in your text which can be used later.

=head2 Conditional statements

Text::Vpp understands @IF, @ELSIF, @ENDIF,and so on.  @INCLUDE and @IF
can be nested.

@IF and @ELSIF are followed by a Perl expression which will be evaled using
the variables you have defined (either with setVar() or in the text).

=head2 Loop statements

Text::Vpp also understands

@FOREACH $MyLoopVar ( Perl-List-Expression )
... (any) lines which may depend on $MyLoopVar
@ENDFOR

These loops may be nested.

=head2 Inclusion

Text::Vpp understands
@INCLUDE  'Filename' or Perl-String-Expression

Note that the file name B<must> be quoted.

=head1 Constructor

=head2 new(file_name, optional_var_hash_ref, ...)

The constructor call
C<new(file_name, optional_var_hash_ref,optional_action_char,>
C<               optional_comment_char, optional_prefix_char,>
C<                                      optional_backslash_switch);>

creates the Vpp object. The second parameter can be a hash containing all
variables needed for the substitute method, the following (optional)
parameters specify the corresponding special characters.

=cut

=head1 Methods

=head2 substitute([output_file])

Perform the substitute, inclusion, and so on and write the result in 
I<output_file>. 
Returns 1 on completion, 0 in case of an error.

If output_file is not specified this function stores the substitution result
in an internal variable. The result can be retrieved with getText()

 You may prefix the filename with >> to get the output
 appended to an existing file.

=cut

#'
=head2 getText()

  Returns an array ref containing the result. You can then get the total
  file with  join "\n",@{VppObj->getText}

=cut

=head2 getErrors()

Returns an array ref containing the errors.

=cut

# Autoload methods go after __END__ and are processed by the autosplit program.

=head2 setVar( key1=> value1, key2 => value2 ,...) or setVar(hash_ref)

Declare variables for the substitute.
Note that calling this function clobbers previously stored values.

=cut

sub setVar 
  {
    my $self = shift ;
    
    if (ref($_[0]) eq 'HASH')
      {
        $self->{var} = shift ;
      }
    else
      {
        %{$self->{var}} = @_ ;
      }
  }

=head2 setActionChar(char)

Enables the user to use different char as action char. (default @)

Example: setActionChar('#') will enable Vpp to understand #include, #ifdef ..

=cut

sub setActionChar
  {
    my $self =shift ;
	
    $self->{action} = shift ;
  }

=head2 setCommentChar(char)

Enables the user to use different char as comment char. (default #)
This value may be set to undef so that no comments are possible.

=cut

sub setCommentChar
  {
    my $self =shift ;
	
    $self->{comment} = shift ;
  }

=head2 setPrefixChar(char)

Enables the user to use different char as prefix char, i.e. variables
in your text (only) are prefixed by that character instead of the
default '$'. Note, that all variables in 'actions' (like @@ @EVAL @FOREACH @IF)
must still be prefixed by '$'.

=cut

sub setPrefixChar
  {
    my $self =shift ;
    my $prefix = shift;
    $self->{prefix}    = $prefix ;
    $self->{VarPat}    = qr/\Q$prefix\E({?)(\w+)\b(}?)/;
  }


=head2 ignoreBackslash()

By default, line ending with '\' are glued to the following line (like in
ksh). Once this method is called '\' will be left as is.

=cut

sub ignoreBackslash
  {
    my $self =shift ;
	
    $self->{backslash} = 0 ;
  }

sub snitch
  {
    my $self = shift ;
    my $msg = shift ;
    my $emsg = "Error in $self->{name} line ".
      $self->{fileDesc}->input_line_number. " : $msg\n" ;

    push @{$self->{errorText}}, $emsg ;
    $self->{error} = 1;
    warn ($emsg);
  }

=head1 CAVEATS

Version 1.0 now requires files included with '@INCLUDE' to be quoted.

=head1 AUTHOR

Dominique Dumont    Dominique_Dumont@grenoble.hp.com

Copyright (c) 1996-1998 Dominique Dumont. All rights reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

Additional bugs have been introduced by
Helmut Jarausch    jarausch@igpm.rwth-aachen.de

=head1 VERSION

Version 1.0

=head1 SEE ALSO

perl(1),Text::Template(3).

=cut
