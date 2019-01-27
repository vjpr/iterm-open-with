#!/bin/sh
# iterm_open_with - open a URL, file from CWD, full path, or path with linenumber in default app or Sublime Text if text file
#                   For usage with iTerm2:
#                   In iTerm's Preferences > Profiles > Default > Advanced > Semantic History,
#                   choose "Run command..." and enter "/your/path/to/iterm_open_with \5 \1 \2".
# Usage: iterm_open_with $(pwd) filename [linenumber]
# $(pwd) = current working directory (either use `pwd` or $PWD)
# filename = filename to open
# lineno = line number
pwd=$1
file=$2

# TO DEBUG RUN: 'tail -f /tmp/iterm_open_with_debug.txt' and use 'echo foo >> $DEBUG_FILE'.

containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

DEBUG_FILE=/tmp/iterm_open_with_debug.txt

iterm_pwd=$1
iterm_filename=$2
iterm_line_no=$3
iterm_text_before_click=$4
iterm_text_after_click=$5

# echo "$1 $2" >> $DEBUG_FILE
echo "ARGS START" >> $DEBUG_FILE
echo "1 (cwd): $iterm_pwd\n2 (filename): $iterm_filename\n3 (line no): $iterm_line_no\n4 (text before click): $iterm_text_before_click\n5 (text after click): $iterm_text_after_click\n" >> $DEBUG_FILE
echo "ARGS END" >> $DEBUG_FILE

# Strip square brackets from string. iTerm seems to match [/foo/bar]
file=$(echo $file | sed 's/[][]//g')

echo "stripped file: $file" >> $DEBUG_FILE

regex='https?://([a-z0-9A-Z]+(:[a-zA-Z0-9]+)?@)?[-a-z0-9A-Z\-]+(\.[-a-z0-9A-Z\-]+)*((:[0-9]+)?)(/[a-zA-Z0-9;:/\.\-_+%~?&amp;@=#\(\)]*)?'

perl -e "if ( \"$file\" =~ m|$regex|) { exit 0 } else { exit 1 }"
if [ $? -ne 0 ]; then
  echo "not an url" >> $DEBUG_FILE
  # if it's not a url, try splitting by ':'
  arr=($(echo $file | tr ':' "\n"))
  file=${arr[0]}
  echo "file: ${arr[0]}" >> $DEBUG_FILE
  echo "arr: ${arr[1]}" >> $DEBUG_FILE
  # lineno=${arr[1]:-$3} // This seemed to me messing up.
  lineno=${arr[1]}
  # colno=${arr[2]:-${3##*:}} // This also seemed to be messing up.
  colno=${arr[2]}
  echo [ -e "$file" ] >> $DEBUG_FILE
  if ![ -e "$file" ]; then
    echo "file didn't exist: ${file}" >> $DEBUG_FILE
    file=${pwd}/${file}
  fi
fi

# Strip quotes.
#   See https://stackoverflow.com/a/46115001/130910
file=$(eval echo $file)

echo "\n" >> $DEBUG_FILE
echo "file: $file" >> $DEBUG_FILE
echo "lineno: $lineno" >> $DEBUG_FILE
echo "colno: $colno" >> $DEBUG_FILE

# TODO: Probably roll the following into one check but didn't have time.

# If its not a file/dir, we use 'open'.
# file "$file"
# if [ $? -ne 0 ]; then
#   echo "is not a file" >> $DEBUG_FILE
#   /usr/bin/open $file
#   exit 0
# fi

# If its not a text file or dir.
# file "$file" | grep -q "text"
file "$file" | grep -q 'text\|directory'
if [ $? -ne 0 ]; then
  echo "not a text file or dir" >> $DEBUG_FILE
  /usr/bin/open $file
  exit 0
fi  

# If its a file or dir...

echo "is a file or dir" >> $DEBUG_FILE

filename=$(basename "$file")
ext="${filename##*.}"

echo "$filename" >> $DEBUG_FILE
echo "$ext" >> $DEBUG_FILE

# Open these extensions in CLion.
clionExts=("h" "cpp" "c")

containsElement "$ext" "${clionExts[@]}"
if [ $? -eq 0 ]; then
  # CLion > CLion > RemoteCall
  curl "http://localhost:8091?message=${file}${lineno:+:${lineno}}"
  # LinCastor > CLion > RemoteCall
  # open "chrome-remote-call://${file}${lineno:+:${lineno}}" 
  # CLion
  # NOTE: Does not show file.
  # open "clion://open?file=${file}&line=${lineno}"
else
  # IntelliJ

  if [[ "$file" =~ "node_modules" ]] ; then

    # This if-branch may not be needed. The API might be able to handle excluded dirs too.
    # NOTE: It does not seem to bring correct IDE window to front. That's why I think we thought it wasn't working once.

    if [ -d "$file" ] ; then
      # Directory.
      
      # url="http://localhost:8091?message=${file}"
      # echo "opening with http://localhost:8091 (RemoteCall plugin) in Intellij: $url" >> $DEBUG_FILE
      # --

      url="http://localhost:63342/api/file/${file}"
      echo "opening url in intellij: $url" >> $DEBUG_FILE

      curl $url
    else
      # NOTE: When passing a dir to 'idea://open?', it will create a new project from $file.
      url="idea://open?file=${file}&line=${lineno}"
      echo "opening with idea:// in intellij: $url" >> $DEBUG_FILE
      open $url
    fi

  else
  
    # We use IntelliJ Platform REST API because it works with folders.
    # See https://www.develar.org/idea-rest-api/#api-Platform-diff for docs.
    if [ -d "$file" ] ; then
      # Is directory.
      echo "Is Directory" >> $DEBUG_FILE
      # url="http://localhost:8091?message=${file}"
      url="http://localhost:63342/api/file/${file}?focused=true"
    else
      echo "Is File" >> $DEBUG_FILE
      # url="http://localhost:8091?message=${file}${lineno:+:${lineno}}${colno:+:${colno}}"
      url="http://localhost:63342/api/file/${file}${lineno:+:${lineno}}${colno:+:${colno}}"
    fi  
    echo "opening url in intellij: $url" >> $DEBUG_FILE
    curl $url

  fi

fi

# TODO(vjpr): Look for `.idea` directory, or even if there is a project open in that directory.

# Sublime
#/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl ${file}${lineno:+:${lineno}}${colno:+:${colno}}


# NOTE: Use to be `Open URL...` ->`idea://open?file=\1&line=\2` in iTerms semantic history action.

# TODO: Rewrite as a node script.