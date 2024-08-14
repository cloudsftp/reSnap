lz4=${lz4:-./lz4.arm.static}

REMARKABLE_PASSWORD=$1
if [ -z "$REMARKABLE_PASSWORD" ]; then
    echo "Please provide the password for the remarkable tablet"
    exit 1
fi
if [ ! -e "$KEY_PATH" ]; then
    ssh-keygen -t $KEY_TYPE -f "$KEY_PATH" -N "" -C "$KEY_COMMENT"

    if [ $? -eq 0 ]; then
        echo "SSH key pair successfully generated"
    else
        echo "Error: SSH key pair generation failed."
        exit 1
    fi
fi
echo "Private key: $KEY_PATH"
echo "Public key:  $KEY_PATH.pub"
echo "Public key content:"
cat "$KEY_PATH.pub"

sshpass -p "$REMARKABLE_PASSWORD" ssh root@10.11.99.1 "mkdir -p ~/.ssh && \
    touch .ssh/authorized_keys && \
    chmod -R u=rwX,g=,o= ~/.ssh && \
    cat >> .ssh/authorized_keys" < "$KEY_PATH".pub
echo "Copied over key pair"

echo "Setting up remarkable for screen captures..."
scp -i "$KEY_PATH" "$lz4" root@10.11.99.1:/home/root/lz4
ssh root@10.11.99.1 -i "$KEY_PATH" 'chmod +x /home/root/lz4'
echo "Placed lz4 on remarkable"

