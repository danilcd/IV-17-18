# -*- cperl -*-

use Test::More;
use Git;
use LWP::Simple;
use File::Slurper qw(read_text);


use v5.14; # For say

my $repo = Git->repository ( Directory => '.' );
my $diff = $repo->command('diff','HEAD^1','HEAD');
my $diff_regex = qr/a\/proyectos\/hito-(\d)\.md/;
my $github;

SKIP: {
  my ($this_hito) = ($diff =~ $diff_regex);
  skip "No hay envío de proyecto", 5 unless defined $this_hito;
  my @files = split(/diff --git/,$diff);
  my ($diff_hito) = grep( /$diff_regex/, @files);
  say "Tratando diff\n\t$diff_hito";
  my @lines = split("\n",$diff_hito);
  my @adds = grep(/^\+[^+]/,@lines);
  is( $#adds, 0, "Añade sólo una línea");
  my $url_repo;
  if ( $adds[0] =~ /\(http/ ) {
    ($url_repo) = ($adds[0] =~ /\((http\S+)\)/);
  } else {
    ($url_repo) = ($adds[0] =~ /^\+.+(http\S+)/s);
  }
  say $url_repo;
  isnt($url_repo,"","El envío incluye un URL");
  like($url_repo,qr/github.com/,"El URL es de GitHub");
  my ($user,$name) = ($url_repo=~ /github.com\/(\S+)\/(.+)/);
  my $repo_dir = "/tmp/$user-$name";
  if (!(-e $repo_dir) or  !(-d $repo_dir) ) {
    mkdir($repo_dir);
    `git clone $url_repo $repo_dir`;
  }
  my $student_repo =  Git->repository ( Directory => $repo_dir );
  my @repo_files = $student_repo->command("ls-files");
  say "Ficheros\n\t→", join( "\n\t→", @repo_files);
  for my $f (qw( README.md .gitignore LICENSE )) {
    isnt( grep( /$f/, @repo_files), 0, "$f presente" );
  }

  if ( $this_hito > 0 ) { # Comprobar milestones y eso 
    cmp_ok( how_many_milestones( $user, $name), ">=", 3, "Número de hitos correcto");
    
    my @closed_issues =  closed_issues($user, $name);
    cmp_ok( $#closed_issues , ">=", 0, "Hay ". scalar(@closed_issues). " issues cerrado(s)");
    for my $i (@closed_issues) {
      my ($issue_id) = ($i =~ /issue_(\d+)/);
      
      is(closes_from_commit($user,$name,$issue_id), 1, "El issue $issue_id se ha cerrado desde commit")
    }
  }

  if ( $this_hito > 1 ) { # Comprobar milestones y eso 
    isnt( grep( /.travis.yml/, @repo_files), 0, ".travis.yml presente" );
    my $README =  read_text( "$repo_dir/README.md"),;
    like( $README, qr/.Build Status..https:\/\/travis-ci.org\/$user\/$name/);
  }
};

done_testing();

sub how_many_milestones {
  my ($user,$repo) = @_;
  my $page = get( "https://github.com/$user/$repo/milestones" );
  my ($milestones ) = ( $page =~ /(\d+)\s+Open/);
  return $milestones;
}

sub closed_issues {
  my ($user,$repo) = @_;
  my $page = get( "https://github.com/$user/$repo".'/issues?q=is%3Aissue+is%3Aclosed' );
  my (@closed_issues ) = ( $page =~ m{<li\s+(id=.+?</li>)}gs );
  return @closed_issues;

}

sub closes_from_commit {
  my ($user,$repo,$issue) = @_;
  my $page = get( "https://github.com/$user/$repo/issues/$issue" );
  return $page =~ /closed\s+this\s+in/gs ;

}
