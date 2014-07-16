user : pass : ''
  <?php
  if(empty($_GET['user']) || empty($_GET['pass'])) {
    header('HTTP/1.1 400 Bad Request');
    die('Invalid query.');
  } else if(strcmp($_GET['user'], '${user}')==0 && strcmp($_GET['pass'], '${pass}')==0) {
    echo('Great! Valid user/pass!');
  } else {
    header('HTTP/1.1 403 Forbidden');
    die('Bad user/pass.')
  }
  ?>
''
