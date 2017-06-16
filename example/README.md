# Example apps
```
                                    --> user-app
client -> front-app -> recipe-app -|
                                    --> campain-app
```

To simulate xray-agent, this example runs socat which prints given bytes to STDOUT.

## Running without xray-agent
At first, install [socat](http://www.dest-unreach.org/socat/).

```
bundle install
bundle exec foreman start
```

Then try:

```
curl localhost:3000/
```

## Running with xray-agent
Follow official document to install xray-agent: http://docs.aws.amazon.com/xray/latest/devguide/xray-daemon.html

Run xray-agent on localhost. Usually it recieves packats at UDP:2000.

Run example apps without socat like:

```
bundle exec foreman start -m 'front=1,recipe=1,user=1,campain=1'
```
