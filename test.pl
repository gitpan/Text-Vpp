# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..17\n"; }
END {print "not ok 1\n" unless $loaded;}
use Text::Vpp;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# will load a text file, set some variables and compare the output

$fin = new Text::Vpp("text_in.txt") ;
$fin->setVar('var1' => 'was set in calling script') ;

my $ret = $fin -> substitute() ;

my $expect = 
"Sample text for Text::Vpp
Some included text

We shoud see this line from included file
We should see this line

We should see this line if var1 was set by perl
var 1 is: was set in calling script.

Should see this one.

" ;

if ($ret)
  {
	print "ok 2\n";
  }
else
  {
	print "not ok 2\n";
	print @{$fin->getErrors()} ;
  }

my $res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 3\n";
  }
else
  {
	print "not ok 3\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }



# Test the ELSIF construct.

$fin = new Text::Vpp("text_elsif.txt") ;
$fin->setVar('var1' => 3) ;

$ret = $fin -> substitute() ;

$expect =  "Sample text for Text::Vpp using ELSEIF
We should see this line, because var1 should be 3
" ;

if ($ret)
  {
	print "ok 4\n";
  }
else
  {
	print "not ok 4\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 5\n";
  }
else
  {
	print "not ok 5\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }


# test backslash stuff
$fin = new Text::Vpp("text_backslash.txt") ;

$expect =  "first line next line\n\nsecond line\n" ;

$ret = $fin -> substitute() ;

if ($ret)
  {
	print "ok 6\n";
  }
else
  {
	print "not ok 6\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 7\n";
  }
else
  {
	print "not ok 7\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }

# test ignore backslash stuff
$fin = new Text::Vpp("text_backslash.txt") ;
$fin->ignoreBackslash;

$expect =  "first line \\\nnext line\n\nsecond line\n" ;

$ret = $fin -> substitute() ;

if ($ret)
  {
	print "ok 8\n";
  }
else
  {
	print "not ok 8\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 9\n";
  }
else
  {
	print "not ok 9\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }


# test action Char 
$fin = new Text::Vpp("text_action.txt") ;
$fin->ignoreBackslash;

$expect =  "included text\n\nSome more text\n\n";
$fin->setActionChar('^');
$fin->setVar('foo' => 1);

$ret = $fin -> substitute() ;

if ($ret)
  {
	print "ok 10\n";
  }
else
  {
	print "not ok 10\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 11\n";
  }
else
  {
	print "not ok 11\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }


#redo the subsitute for fun
$ret = $fin -> substitute() ;

if ($ret)
  {
	print "ok 12\n";
  }
else
  {
	print "not ok 12\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 13\n";
  }
else
  {
	print "not ok 13\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }

# test FOREACH loop and substitution patter
 
$fin = new Text::Vpp("for_subs.txt") ;
$fin->setPrefixChar('\\');

$expect = <<'EOExp';
Sample text for demonstrating loops and subsitution patterns
numbers 0: 0  and  3: 3 on this line
 print this line

---------------------
generated line: 1 column: 7 position 7 <<<
generated line: 1 column: 11 position 11 <<<
---------------------
generated line: 2 column: 7 position 87 <<<
generated line: 2 column: 11 position 91 <<<
---------------------
generated line: 3 column: 7 position 167 <<<
generated line: 3 column: 11 position 171 <<<

last line
EOExp

$fin->setVar(Real => 1, Complex => 0);

$ret = $fin -> substitute() ;

if ($ret)
  {
	print "ok 14\n";
  }
else
  {
	print "not ok 14\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 15\n";
  }
else
  {
	print "not ok 15\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }

$fin = new Text::Vpp("advanced.txt") ;
$fin->setPrefixChar('\\');

$expect = <<'EOExp';

now two actions in one line === 3.14159265358979 ---  hello world  EOL
you shouldn't see the following empty loop
Now a loop with a 'computed' list
 expanded Forlist 1. line
 expanded Forlist 2. line
EOExp

$fin->setVar(Real => 1, Complex => 0);

$ret = $fin -> substitute() ;

if ($ret)
  {
	print "ok 16\n";
  }
else
  {
	print "not ok 16\n";
	print @{$fin->getErrors()} ;
  }

$res = join("\n",@{$fin->getText()})."\n" ;

if ($res eq $expect)
  {
	print "ok 17\n";
  }
else
  {
	print "not ok 17\n",
	"expect\n---\n",$expect,"---\n",
	"got   \n---\n",$res,   "---\n";
  }

