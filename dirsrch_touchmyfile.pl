# ========== FTPサイトのファイルのタイムスタンプを更新するツール ==========

use strict;
use warnings;
use Net::FTP;
use IO::Handle;

  our ($ftp, $acnt, $pswd, @ftps, $lf, $pasv, $wdir, $host, $patf, $patd);

  # ===== 設定値1 ===================

  $host = 'ftp.dokoka.no.jp';                   # ホスト名
  $pasv = 0;                                    # PASVモードにするなら非0に
  $acnt = 'tarou';                              # アカウント
  $pswd = 'xyz12345';                           # パスワード
  $wdir = 'C:\WORK\ftp\wk';                     # DownLoad用作業ディレクトリ
  $lf = 'C:\WORK\ftp\logfile.err';              # 処理中ログファイル

  $patd = '^\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.+)$';
    # ホストへのdirメソッドの結果の正規表現
    # ディレクトリ名が $1 で参照出来る事

  $patf = '^(\S+)\s+\S+\s+' . $acnt .
    '\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.+)$';
    # ホストへのdirメソッドの結果の正規表現
    # ファイル名が $2、パーミッションが $1 で参照出来る事

  # ===== 設定値2 ===================
  # ホスト上の処理対象のディレクトリ

  $ftps[0] = 'abc';
  $ftps[1] = 'def';

  # =================================

  unless ($ftp = Net::FTP -> new($host, Debug => 0, Passive => $pasv)) {
    die 'Internal Error … Net::FTP のオブジェクトが作れません';
  }
  die 'FTPサイトにログイン出来ません' unless ($ftp -> login($acnt, $pswd));
  die 'DownLoad用作業ディレクトリに移動出来ません' unless (chdir $wdir);
  die '処理中ログファイルが残っています' if (-e $lf);
  die 'binaryモードに変更出来ません' unless ($ftp -> binary());
  foreach my $d (@ftps) {
    die $d . ' に移動(cwdメソッド)出来ません' unless ($ftp -> cwd($d));
  }

  &dirsrch_getmyfile();

  $ftp -> quit;

sub dirsrch_getmyfile {
  my ($r, $f, @randf);

  {
    my ($cou, $fib0, $fib1, $fib2);
    ($cou, $fib0, $fib1) = (10, 1, 0);
    do {
      my ($err);
      die join('/', @ftps) . ' に移動(cwdメソッド)出来ません' if ($cou <= 0);
      $err = 0;
      if ($cou < 10) {
        $ftp -> quit;
        sleep($fib0);
        undef $ftp;
        $ftp = Net::FTP -> new($host, Debug => 0, Passive => $pasv);
        $ftp -> login($acnt, $pswd) or $err ++;
        $ftp -> binary() or $err ++;
        for (my $i0 = 0; $i0 < @ftps; $i0 ++) {
          $ftp -> cwd($ftps[$i0]) or $err ++;
        }
      }
      $cou --;
      $fib2 = $fib1;
      $fib1 = $fib0;
      $fib0 = $fib1 + $fib2;
      if ($err == 0) {
        my ($alrm);
        $alrm = $SIG{ALRM};
        eval {
          $SIG{ALRM} = sub { die 'timeout' };
          alarm $fib0 + 5;
          $r = $ftp -> dir();
          alarm 0;
        };
        alarm 0;
        $SIG{ALRM} = $alrm;
        $r = '' if ($@);
      }
      else {
        $r = '';
      }
    } while (!$r);
  }

  @randf = ();
  foreach ( @{$r} ) {
    my $r0 = int(rand(@randf + 1));
    push @randf, $randf[$r0];
    $randf[$r0] = $_;
  }
  foreach $f ( @randf ) {
    if (substr($f, 0, 1) eq 'd') {
      if ($f =~ /$patd/) {
        my ($d);
        $d = $1;
        if ($ftp -> cwd($d)) {
          push @ftps, $d;
          &dirsrch_getmyfile();
          {
            my ($cou, $fib0, $fib1, $fib2, $r1);
            ($cou, $fib0, $fib1) = (10, 1, 0);
            do {
              my ($err);
              if ($cou <= 0) {
                die join('/', @ftps) .
                  ' から親ディレクトリに移動(cdupメソッド)出来ません';
              }
              $err = 0;
              if ($cou < 10) {
                my ($i1);
                $ftp -> quit;
                sleep($fib0);
                undef $ftp;
                $ftp = Net::FTP -> new($host, Debug => 0, Passive => $pasv);
                $ftp -> login($acnt, $pswd) or $err ++;
                $ftp -> binary() or $err ++;
                for ($i1 = 0; $i1 < @ftps; $i1 ++) {
                  $ftp -> cwd($ftps[$i1]) or $err ++;
                }
              }
              $cou --;
              $fib2 = $fib1;
              $fib1 = $fib0;
              $fib0 = $fib1 + $fib2;
              if ($err == 0) {
                my ($alrm);
                $alrm = $SIG{ALRM};
                eval {
                  $SIG{ALRM} = sub { die 'timeout' };
                  alarm $fib0;
                  $r1 = $ftp -> cdup();
                  alarm 0;
                };
                alarm 0;
                $SIG{ALRM} = $alrm;
                $r1 = '' if ($@);
              }
              else {
                $r1 = '';
              }
            } while (!$r1);
          }
          pop @ftps;
        }
      }
      else {
        die 'dirメソッドの出力フォーマットが不正です';
      }
    }
    elsif (substr($f, 0, 1) eq '-') {
      if ($f =~ /$patf/) {
        my ($fil, $p, $mode, $i, $cou, $fib0, $fib1, $fib2, $fp, $r1);
        ($p, $fil, $mode) = ($1, $2, '');
        for ($i = 0; $i < 3; $i ++) {
          my ($j, $m);
          $m = 0;
          for ($j = 0; $j < 3; $j ++) {
            if (substr($p, 1 + $i * 3 + $j, 1) ne '-') {
              $m |= 2 ** (2 - $j);
            }
          }
          $mode .= $m;
        }
        $fp = IO::Handle -> new();
        die 'ログファイルに書き込めません' unless (open $fp, '> ' . $lf);
        $fp -> autoflush(1);
        print $fp join('/', @ftps) . '/' . $fil . "\n";
        close $fp;
        unless ($ftp -> get($fil)) {
          unlink $lf;
          next;
        }
        ($cou, $fib0, $fib1) = (10, 1, 0);
        do {
          my ($err);
          die 'ファイルを置き直す(putメソッド)事が出来ません' if ($cou <= 0);
          $ftp -> delete($fil);
          $err = 0;
          if ($cou < 10) {
            my ($i1);
            $ftp -> quit;
            sleep($fib0);
            undef $ftp;
            $ftp = Net::FTP -> new($host, Debug => 0, Passive => $pasv);
            $ftp -> login($acnt, $pswd) or $err ++;
            $ftp -> binary() or $err ++;
            for ($i1 = 0; $i1 < @ftps; $i1 ++) {
              $ftp -> cwd($ftps[$i1]) or $err ++;
            }
          }
          $cou --;
          $fib2 = $fib1;
          $fib1 = $fib0;
          $fib0 = $fib1 + $fib2;
          if ($err == 0) {
            my ($alrm);
            $alrm = $SIG{ALRM};
            eval {
              $SIG{ALRM} = sub { die 'timeout' };
              alarm 119;
              $r1 = $ftp -> put($fil);
              alarm 0;
            };
            alarm 0;
            $SIG{ALRM} = $alrm;
            $r1 = '' if ($@);
          }
          else {
            $r1 = '';
          }
        } while (!$r1);
        $ftp -> site('CHMOD ' . $mode . ' ' . $fil);
        unlink $fil, $lf;
      }
    }
  }
}

__END__
