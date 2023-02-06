#!/bin/bash

#sed -i 's/\/c\\$pinpoint/\/pinpoint/g' reindex.lst

while IFS=',' read -r line; 
do IFS=',' read -r -a commands <<< "$line" 
if [[ -n "$line" ]]; then
sudo -i -u oracle bash <<EOF
${commands[0]} <<EOL
${commands[1]}
${commands[2]}
exit
EOL
EOF
fi
done < reindex.lst
