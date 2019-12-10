---
layout: post
title:  "Indy Exploration!"
date:   2019-12-10
categories: Indy
---

# Guide to Indy SDK source code through practical examples and Use Cases

## Users (DIDs & authcrypted exchanges)

In this part of the tutorial we are going to touch main aspects of the Indy Hyperledger, concerning the user and the creation of the identifiers.

We will use the same names as the fictitious characters that Hyperledger released for their introductory exposition about the ledger.

We will understand how users with a specific role can write new dids into the ledger. Such a procedure will get the name of nym transaction. For instance, we say that a new did is created after a nym transaction is sent to the ledger.

We will establish a cryptographically secure information exchange between two parties.

Nevertheless, in this version there is not a back channel through which the users can exchange the encrypted information.

Indeed, for the sake of understanding we focus here on what the users are exchanging outside the ledger rather than how they could do it.

Therefore following the statement “Alice sends X to Bob” we will make a hard copy of the information owned by Alice into the data structure representing the user Bob by using a variable.

At first we will show all the steps in a practical example. Consequently we will abstract such a procedure and refer to it with the name of onboarding.


# Initial Setups


```python
from indy import anoncreds, crypto, did, ledger, pool, wallet
import os, json, time
from collections import defaultdict
```


```python
# procedures we wrote to support the notebook examples
from supporting_procedures import (prover_create_revocation_states, extract_revocation_time_from_proof_request,
                           verifier_get_revocation_info_for_proof_verification)
```

We set up the pool we are going to use in this tutorial with the configuration file attached to the repo


```python
from indy.error import PoolLedgerConfigAlreadyExistsError
```


```python
# keep memory of the handle to close the pool in case of error
pool_handle_for_closing = None
```

We create and open the pool


```python
pool_genesis_txn_path = os.path.join(os.pardir,"config-file.txt")
pool_config = json.dumps({"genesis_txn": str(pool_genesis_txn_path)})
pool_name = 'pool1'
await pool.set_protocol_version(2)

```


```python
async def create_and_open_pool(pool_name, pool_config):
    global pool_handle_for_closing
    await pool.create_pool_ledger_config(pool_name, pool_config)
    print("Pool successfully created")
    print("Establishing a connection to the pool ...")
    pool_handle = await pool.open_pool_ledger(pool_name, None)
    print("Connection Established! Pool handle: {}".format(pool_handle))
    try:
        pool_handle
    except NameError:
        pool_handle = None

    if pool_handle is not None:
        pool_handle_for_closing = pool_handle


```


```python
try:
    await create_and_open_pool(pool_name, pool_config)
except:
    print("A pool with such a configuration was already existing")
    try:
        await pool.delete_pool_ledger_config(pool_name)
        print("The pool has been deleted!\nCreation of a new one...")
        await create_and_open_pool(pool_name, pool_config)
    except:
        print("It seems the pool is still opened.\nClosing the pool")
        await pool.close_pool_ledger(pool_handle_for_closing)
        ("The pool has been closed!")
        await pool.delete_pool_ledger_config(pool_name)
        ("The pool has been deleted!\nCreation of a new one...")
        await create_and_open_pool(pool_name, pool_config)

```

    A pool with such a configuration was already existing
    The pool has been deleted!
    Creation of a new one...
    Pool successfully created
    Establishing a connection to the pool ...
    Connection Established! Pool handle: 2


**NB**
In the above we forced the creation of the pool by removing the already existing one if necessary. Indeed the aim of this notebook is to explain the internals of the sdk and the code is run in a docker container. This procedure can cause on a host machine to remove pools with the same name that the user was using.


```python
# we retrieve the last available pool_handle to be used later
pool_handle = pool_handle_for_closing
```

# First steps with the agents

We are running an instance of the ledger where a Steward agent is preconfigured. In particular, the DID, created using a seed, has been given a role that allows her to send nym transactions to the ledger.

It suffices to say that a nymtransaction is the transaction sent to the ledger that registers the objective DID with the desired role.


```python
steward = {
  'name': "Sovrin Steward",
  'wallet_config': json.dumps({'id': 'sovrin_steward_wallet'}),
  'wallet_credentials': json.dumps({'key': 'steward_wallet_key'}),
  'pool': pool_handle,
  'seed': '000000000000000000000000Steward1'
}
await wallet.create_wallet(steward['wallet_config'], steward['wallet_credentials'])
steward['wallet'] = await wallet.open_wallet(steward['wallet_config'], steward['wallet_credentials'])

```

We create a DID for the Steward using the configuration specified above


```python
# Creation of the did using the seed specified above
steward['did_info'] = json.dumps({'seed': steward['seed']})
steward['did'], steward['key'] = await did.create_and_store_my_did(steward['wallet'], steward['did_info'])
```


```python
steward['did']
```




    'Th7MpTaRZVRYnPiabds81Y'



For the sake of understanding the process, we create a new did for the Steward using another 32bytes seed


```python
# Creation of the did using another seed
# we use a 32bytes string as seed
did_json_config = json.dumps({'seed': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'})
new_did, new_key = await did.create_and_store_my_did(steward['wallet'], did_json_config)
new_did,new_key
```




    ('NcYxiDXkpYi6ov5FcYDi1e', 'CnEDk9HrMnmiHXEV1WFgbVCRteYnPqsJwrTdcZaNhFVW')



## Government asks to be assigned a role of Trust Anchor (TA)

In this section, the aim of the Government is to register one of its DIDs with the role of TA.

The Steward is responsible for the registration on the ledger.

But before such a registration takes place, the Steward, needs to establish a secure connection with the Government in order to assess its identity.

The process works like this:
- Government creates adhoc DID and verkey for connection with the Steward
- Steward creates adhoc DID and verkey for connection with the Government
- They establish a cryptographically secure connection using the previous created DIDs and keys
- Government solves a random challenge sent by the Steward
- Government creates a new DID and asks the Steward to register that DID into the ledger with TA role


```python
# create a wallet for the Govt.
government = {
    'name': 'Government',
    'wallet_config': json.dumps({'id': 'government_wallet'}),
    'wallet_credentials': json.dumps({'key': 'government_wallet_key'}),
    'pool': pool_handle,
    'role': 'TRUST_ANCHOR'
}
await wallet.create_wallet(government['wallet_config'], government['wallet_credentials'])
government['wallet'] = await wallet.open_wallet(government['wallet_config'], government['wallet_credentials'])
```


```python
# create a Govt did to be used in the onboarding with the Steward
# govt_did_for_steward := the did Govt creates to interact with the Steward
# govt_key_for_steward := the ver key assigned to the did above

govt_did_for_steward, govt_key_for_steward = await did.create_and_store_my_did(government['wallet'], "{}")
govt_did_for_steward,govt_key_for_steward
```




    ('PYLfff9GdRNiNiuerEDjYU', 'DHYZogrV1S8r8LVXuXfN2PYcPSETKJ8FYgSqXAYkR4Pz')



Later, the Steward does the same and creates a DID and a verkey with which she will interact with the Government.


```python
# from: Steward --- to: Government
# create adhoc dids for the onboarding between steward and govt.
(steward_did_for_govt, steward_key_for_govt) = await did.create_and_store_my_did(steward['wallet'], "{}")
(steward_did_for_govt,steward_key_for_govt)

```




    ('KvKwFwB7JaHEctS5Y4ppwc', 'BK5eszJ3ATQGXUfRg1ScnDaxKN6QV2zWBvrc5NrzA1PT')



In the previous tuple there are:
    - DID which the Steward will be known with by the Government
    - The Steward's PubKey (verkey) that the Government can use to encrypt data to be sent to the Steward

The Steward sends the nym transaction to the ledger with which she register her new DID created just for the adhoc connection with the Government. Indeed, in this way, the Govt can query the ledger to retrieve the necessary info about such a DID.


```python
# send nym request to ledger
# the steward registers its new did
nym_request = await ledger.build_nym_request(steward['did'], steward_did_for_govt, steward_key_for_govt, None, None)
receipt = await ledger.sign_and_submit_request(steward['pool'], steward['wallet'], steward['did'], nym_request)
receipt
```




    '{"result":{"txn":{"metadata":{"digest":"21cf0d568e6ca6cc06029db1107395f5e904d8a507e441f20bb8651932fe48b7","reqId":1572973231205295985,"payloadDigest":"2440d4e675bb8a42f725efc7fc6de98b46851cdde61c1f3b1510ebcd6fe161d4","from":"Th7MpTaRZVRYnPiabds81Y"},"protocolVersion":2,"type":"1","data":{"verkey":"BK5eszJ3ATQGXUfRg1ScnDaxKN6QV2zWBvrc5NrzA1PT","dest":"KvKwFwB7JaHEctS5Y4ppwc"}},"ver":"1","txnMetadata":{"txnId":"856bf6d5518e6ce3ec48e50a04b92ee2e9c03504e6f75ecdc1832849429f9dff","txnTime":1572973231,"seqNo":11},"auditPath":["EsY4hbw8MPXuyQTiq43pvwJqak6pGzfKwJKMXoi6uYS7","DNHM372JZJoGcxdHdmsj3QSSiomyeZux6ssJXxAJqyvd"],"rootHash":"HBhYKfwYztUDLtZwhuY9qECSDCTyZc5wwFD2ZhgzdQEF","reqSignature":{"type":"ED25519","values":[{"value":"5jbf5xncuCRhqyWrk8yQo9WroWke5GWqmX8weHXKp2Cjv35hgQ5wQRPt4aLu6Rc7uJD3v54SePCwFbUJbZngshA","from":"Th7MpTaRZVRYnPiabds81Y"}]}},"op":"REPLY"}'



Now the ledger knows the existence of the DID that has been created by the Steward.
Note that the Steward, for now, is the only one that can send such requests to the ledger. The registration into the ledger of a did means that any agent can query the ledger and retrieve the public key associated to that did.


The secret challenge can then take place.

Steward sends a connection request to Government. In such a request the Steward places its DID and a random number.

In order to establish the connection Steward <-> Government, the latter needs to answer back the connection request with a secret. Where the secret is an encrypted message with:
1)the random number sent by the Steward
2)the DID of the Government
3)the pubKey associated to that Government DID

The encryption of the message is done by the Government using the pubKey associated to the DID that the Steward sent in the connection request. Such a pubKey can be retrieved by the Government from the ledger since the Steward registered the DID into the ledger at the previous step.

Therefore, the sender of the secret (Government) will encrypt it using the public key of the receiver (Steward). The latter, when got the message, will decrypt it using her private key.



```python
# Steward says: here are my did and my nonce for the challenge
connection_request = {
    'did': steward_did_for_govt,
    'nonce': 123456789
}
connection_request
```




    {'did': 'KvKwFwB7JaHEctS5Y4ppwc', 'nonce': 123456789}



The Government receives such a connection request. The DID *steward_did_for_govt* has been written into the ledger. Therefore the Government can ask the ledger which is the verkey(PubKey) associated to such did


```python
# Govt gets the verkey associated to steward_did_for_govt directly from the ledger
steward_key_for_govt_in_ledger = await did.key_for_did(government['pool'], government['wallet'], connection_request['did'])
steward_key_for_govt_in_ledger
```




    'BK5eszJ3ATQGXUfRg1ScnDaxKN6QV2zWBvrc5NrzA1PT'



Just for explanatory sake we check that the key Governmen retrieves from the ledger is the one got in creation phase by the Steward


```python
assert steward_key_for_govt_in_ledger == steward_key_for_govt
```

Government gets the verkey of the Steward's DID. It uses such a key to encrypt the data that are to be sent to the Steward.

Government writes down ->  here are:
    - my DID (for this pairwise connection)
    - my verkey (PubKey)
    - the random number that you sent me


```python
government['response_for_stward_clear'] = json.dumps({
    'did': govt_did_for_steward,
    'verkey': govt_key_for_steward,
    'nonce': connection_request['nonce']
})
```

The response needs to be sent to the Steward. But before that, it needs to be encrypted.


```python
# Govt. encryptes the previous info using the Steward's Pubkey it got back from the ledger
government['response_for_stward_encrypted'] = \
        await crypto.anon_crypt(steward_key_for_govt_in_ledger,\
                                government['response_for_stward_clear'].encode('utf-8'))
```

Government sends the encrypted msg to the Steward (assuming here a back channel communication)


```python
steward['response_from_Govt_encrypted'] = government['response_for_stward_encrypted']
```

The steward decrypts the msg. In the decryption procedure the Steward provides also her public key, the one that the Government used to encryptes the message. With doing so the procedure will know which private key to use to decrypt.




```python
# To decrypt the Steward provides the vekey she got in creation phase of the did with which she interacts with the Govt.
steward['response_from_Govt_clear'] = \
        json.loads((await crypto.anon_decrypt(steward['wallet'], steward_key_for_govt,
                                              steward['response_from_Govt_encrypted'])).decode("utf-8"))
```

Having decrpyted the message, the Steward takes the secret number and compare it to the one she sent previously


```python
#check if the secret is valid
assert steward['response_from_Govt_clear']['nonce'] == connection_request['nonce']
```

Once the random challenge has been successfully passed, the Steward can trust the message he receives from the Government.

The Steward sends a nym transaction to the ledger in order to save the did the Government creates to interact with her.


```python
nym_request = await ledger.build_nym_request(steward['did'],\
                                             steward['response_from_Govt_clear']['did'] ,\
                                             steward['response_from_Govt_clear']['verkey'],\
                                             None, None)
await ledger.sign_and_submit_request(steward['pool'], steward['wallet'], steward['did'], nym_request)
```




    '{"result":{"reqSignature":{"type":"ED25519","values":[{"from":"Th7MpTaRZVRYnPiabds81Y","value":"57HJKXGnNC42LqUusvfaohSzeqDk42vzudKBbHRNi2krad3MZKcMrgWwkrbK58BRjuW9oR22FNsuP2QeiSEDRQ2r"}]},"txn":{"data":{"verkey":"DHYZogrV1S8r8LVXuXfN2PYcPSETKJ8FYgSqXAYkR4Pz","dest":"PYLfff9GdRNiNiuerEDjYU"},"metadata":{"reqId":1572973231541911576,"from":"Th7MpTaRZVRYnPiabds81Y","digest":"5baf807cdfd4a30a0ad84ec3479ccbc317e2b31fa47856bc8c1a8c70d127f9a4","payloadDigest":"5a8571c4c8133c04cbf046e698f36243f1ae27bb13e34101b22690afd046333a"},"type":"1","protocolVersion":2},"ver":"1","txnMetadata":{"txnId":"31335db3c34cd1aad976184229c927741d5786e9b1855587a2bcee2b6ee02a55","seqNo":12,"txnTime":1572973232},"rootHash":"9Jg4h8gbJojTbWitZRYzaZW6PfqXWXBr8hRdJEd2DwG1","auditPath":["2V4P6itrdFbXvpqdHWSGif7yZRso4qAK9ScgW726yURG","EsY4hbw8MPXuyQTiq43pvwJqak6pGzfKwJKMXoi6uYS7","DNHM372JZJoGcxdHdmsj3QSSiomyeZux6ssJXxAJqyvd"]},"op":"REPLY"}'



Now the DID that Government creates to establish a connection with the Steward is written into the ledger.

Therefore the Steward can securely communicates with such a DID anytime in the future.  

### Attention Point!
The previous DID created by the Government is just for a pairwise connection Government<->Steward. Anytime the Steward wants to send a secret message to the Government she can use the verKey associated to that did to encrypt the message.

But the Government wants to create a new DID that will work as its SSI identifier with a role of TA.

In order for the Government to be assigned the role of TA (at least to one of its dids) the following steps take place:
    - The Government creates a new did
    - The Government sends it to the Steward (in a secure channel)
    - The Steward sends a nym transaction to the ledger. With this, she assignes to the received did the role of TA


```python
# create a new did for Govt.
# save it inside the dictionary data structure used here just to signal that this is the did Govt uses for SSI
government['did'], government['key'] = await did.create_and_store_my_did(government['wallet'], "{}")
```


```python
# create the message to send to the Steward
government['did_info'] = json.dumps({
    'did': government['did'],
    'verkey': government['key']
})
government['did_info']
```




    '{"verkey": "61CEBo3FBCW2hThFbhR6mnCHKnkZmktwLsUmJA8dr1bW", "did": "ABS4UwqvF84EG9h3B6HeL2"}'



Government sends this new DID to the Steward in a secure way (**authenticated encryption**)

The message needs to be encrypted (using pubKey of the receiver) and authenticated (signing with privKey of the sender)

Indeed, the idea of the authenticated encrypton lies on the construction of a shared key. Both the sender and the receiver can create a shared secret key in the following way:

    - Sender computes it using: Receiver(PubKey) + Sender(PrivKey)

    - Receiver computes it using : Receiver(PrivKey) + Sender(PubKey)

The message is encrypted/decrypted using such a shared key

In other words, we could say that:
    - Government encryptes with PubKey_Steward and sign with PrivKey_Govt
    - Steward decrypts with PrivKey_Steward and check signature with PubKey_Govt


```python
# govt_key_for_steward (the sender)
# steward_key_for_govt_in_ledger(the receiver)
authcrypted_government_did_info_json = \
    await crypto.auth_crypt(government['wallet'],govt_key_for_steward, steward_key_for_govt_in_ledger, government['did_info'].encode('utf-8'))
```


```python
# Steward receives the encrypted msg from Govt.
# NOTE: the auth_decrypt method will be deprecated
from_verkey, decrypted_message_json = \
    await crypto.auth_decrypt(steward['wallet'], steward_key_for_govt, authcrypted_government_did_info_json)
govt_did_info = json.loads(decrypted_message_json.decode('utf-8'))
```


```python
from_verkey, govt_did_info
```




    ('DHYZogrV1S8r8LVXuXfN2PYcPSETKJ8FYgSqXAYkR4Pz',
     {'did': 'ABS4UwqvF84EG9h3B6HeL2',
      'verkey': '61CEBo3FBCW2hThFbhR6mnCHKnkZmktwLsUmJA8dr1bW'})



### Check that the keys match

From *auth_decript* the Steward together with a did receives also a verkey. This is the one of the Government(sender).

The Steward then asks the ledger for the key associated to the did she knows for Govt(*govt_did_for_steward*)


```python
#Steward asks the ledger for the verKey of the Govt.
retrived_pubkey_govt_for_steward = await did.key_for_did(steward['pool'], steward['wallet'],govt_did_for_steward)
retrived_pubkey_govt_for_steward
```




    'DHYZogrV1S8r8LVXuXfN2PYcPSETKJ8FYgSqXAYkR4Pz'



The Steward checks that such a key retrieved from the ledger is the same as the one of the sender


```python
assert from_verkey == retrived_pubkey_govt_for_steward
```

Once the Steward successfully checked the key provided by Government, she can trust the agent and send the transaction to the ledger.

This will save the Government did with the given role for it.

*Note* that the sender of a nym transaction needs to be one entitled to do that.

Therefore, although the did register into the ledger refers to the Government, it is the Steward that sends the request. It is, indeed, only the latter to have such a role for now.


```python
nym_request = await ledger.build_nym_request(steward['did'], govt_did_info['did'],
                                             govt_did_info['verkey'], None, 'TRUST_ANCHOR')
await ledger.sign_and_submit_request(steward['pool'], steward['wallet'], steward['did'], nym_request)
```




    '{"result":{"txn":{"metadata":{"digest":"ad32a858cdfe907a394ffb6be8989f28fc326a4e5884f685d90dfa255b9d96ae","reqId":1572973232618832505,"payloadDigest":"b0dbad581b7d6d5ca48004e4ec5c28ec3dfe3e629301e5e5918c57b8d161ddc4","from":"Th7MpTaRZVRYnPiabds81Y"},"protocolVersion":2,"type":"1","data":{"role":"101","dest":"ABS4UwqvF84EG9h3B6HeL2","verkey":"61CEBo3FBCW2hThFbhR6mnCHKnkZmktwLsUmJA8dr1bW"}},"ver":"1","txnMetadata":{"txnId":"99bbf1c7cd18a6682c814f9fbe7214ffae8fc49a9f83df2f2bc0d22820876ad2","txnTime":1572973233,"seqNo":13},"auditPath":["G75enhk9vZ7xu7TAKcMWy7LhxZjvpLhifGb1DkEnxyzc","DNHM372JZJoGcxdHdmsj3QSSiomyeZux6ssJXxAJqyvd"],"rootHash":"A6Lrn3UJd9Jb6yH8q8UZvJPzRnYkPWwUd2AH28hAXek4","reqSignature":{"type":"ED25519","values":[{"value":"9abJmPW4ftqAknpJSJnCShuAPwARVtP7HYpg5R6FLRNLY8gXFdv5keje7ReLYhfgpyGz1YRkZ7LPPTFeDTSLode","from":"Th7MpTaRZVRYnPiabds81Y"}]}},"op":"REPLY"}'



We now show that the DID created above for the Government can send nym transaction as well.

Indeed such a did was added to ledger with the label of "TRUST_ANCHOR".

Let's suppose that the Steward wants to create a new did and ask the Government to save it into the ledger.


```python
#create a new did and a new key for the steward agent
new_did, new_key = await did.create_and_store_my_did(steward['wallet'],'{}')
new_did, new_key
```




    ('WR2YUyjHuTGN2EBsvp9gRx', 'H2qs7iDD65Q2GsfB3t6qwrmHtszft3E1eXSw7Tc3GFHf')



Suppose that there was a secure connection between Steward and Government in which the former communicates the did to be registered to the latter.


```python
#We then send the nym request using the Govt did that has the role of TA
nym_request = await ledger.build_nym_request(government['did'],new_did,
                                             new_key, None, None)
await ledger.sign_and_submit_request(government['pool'], government['wallet'], government['did'], nym_request)
```




    '{"result":{"reqSignature":{"type":"ED25519","values":[{"from":"ABS4UwqvF84EG9h3B6HeL2","value":"2Gk2xvNYENH4yKjx8ioCxLabv7wbj3oAiBm3qViQ7MzvBnqZ8uvBs6Xiirh4UwacjC1bVcofSRBsEp9snSTe6cTe"}]},"txn":{"data":{"verkey":"H2qs7iDD65Q2GsfB3t6qwrmHtszft3E1eXSw7Tc3GFHf","dest":"WR2YUyjHuTGN2EBsvp9gRx"},"metadata":{"reqId":1572973233457083783,"from":"ABS4UwqvF84EG9h3B6HeL2","digest":"05ce94737888006c7a169bd04c50064d81a7a08b4698a36888741e0e5ba4786d","payloadDigest":"b2670c9418a5e7d947ff9fac5ad2bad7b71261a49c821042d35f5385f7bfd09d"},"type":"1","protocolVersion":2},"ver":"1","txnMetadata":{"txnId":"acf63bb11b23a2cf35c611f142348331aa28007369b6c45854e7cbbdf0bf5d0b","seqNo":14,"txnTime":1572973234},"rootHash":"79Vu4xCT4fxmWPYAMWendfg5FUDnuYDRrfBjU598X3ZE","auditPath":["H4kPehoaEGroqLT9TxL86eZoKd91PzHsgMrDk7DAEdx","G75enhk9vZ7xu7TAKcMWy7LhxZjvpLhifGb1DkEnxyzc","DNHM372JZJoGcxdHdmsj3QSSiomyeZux6ssJXxAJqyvd"]},"op":"REPLY"}'



**BUT** what if the transaction is sent by a did that does not have such a role?

For instance let's consider a did registered as common user.

We create a new DID for Government and asks the Steward register it as a common USER (role = None)


```python
# create new did-key for govt
new_gov_did, new_gov_key = await did.create_and_store_my_did(government['wallet'],'{}')
new_gov_did, new_gov_key
```




    ('NcZhyokuNAL3iWdhC8uCqd', 'CnEdKxP8BnEjkPyrDGVjiixCg2aeebXGq493kv8dpAPS')




```python
# make the Steward add them to the ledger but without a specific role
nym_request = await ledger.build_nym_request(steward['did'], new_gov_did,
                                             new_gov_key, None, None)
await ledger.sign_and_submit_request(steward['pool'], steward['wallet'], steward['did'], nym_request)
```




    '{"result":{"txnMetadata":{"txnId":"a1b463699e1e64eccc934b85095fd0c814af6d46ea2d0fc79c62d57c7c265e2b","seqNo":15,"txnTime":1572973235},"txn":{"protocolVersion":2,"type":"1","metadata":{"reqId":1572973234477988861,"from":"Th7MpTaRZVRYnPiabds81Y","payloadDigest":"b5439b0715f7849341b574136fe93b3ea9501b1ff723cc13de5a2d22f3e126e9","digest":"74d1112e28d441e9f789757b91f2943c05885f921adf9bb4f409052ff102d18f"},"data":{"verkey":"CnEdKxP8BnEjkPyrDGVjiixCg2aeebXGq493kv8dpAPS","dest":"NcZhyokuNAL3iWdhC8uCqd"}},"reqSignature":{"type":"ED25519","values":[{"from":"Th7MpTaRZVRYnPiabds81Y","value":"4AmoDUMHMu8L75unWYwXdJdCMknPQA7UXdPKM2Y3WoLFXLzon3NPknGVF7JMsD3kKZEQLqGtjP9wC74uCVpeSgZn"}]},"auditPath":["9zmbvC1YzTxdDs89C58pvUinq69MPESkYXsrre6iz8HR","G75enhk9vZ7xu7TAKcMWy7LhxZjvpLhifGb1DkEnxyzc","DNHM372JZJoGcxdHdmsj3QSSiomyeZux6ssJXxAJqyvd"],"rootHash":"2ScZF5HoZb6VYinqZCWi9BTAjf2x2U3PtkVffp6gJgzW","ver":"1"},"op":"REPLY"}'



Then the Steward creates a new DID

The Government tries to register the just produced Steward's did using the one previoulsy created. As seen, this one had the role of a common user therefore we should expect an error while sending the nymtransaction to the ledger.


```python
# create new pair did-key for the steward wallet
new_did, new_key = await did.create_and_store_my_did(government['wallet'],'{}')
new_did, new_key
```




    ('AasqRkzeJtSh69syd5Yvh2', '6DyMMQSFrzwnD2sVXjBRZJm4GS5kNzwXDsDQggpBXJix')




```python
# try to use the govt did with a user role to send a nym transaction
nym_request = await ledger.build_nym_request(new_gov_did,new_did,
                                             new_key, None, None)
await ledger.sign_and_submit_request(government['pool'], government['wallet'], new_gov_did, nym_request)
```




    '{"reason":"client request invalid: UnauthorizedClientRequest(\'Rule for this action is: 1 TRUSTEE signature is required OR 1 STEWARD signature is required OR 1 ENDORSER signature is required\\\\nFailed checks:\\\\nConstraint: 1 TRUSTEE signature is required, Error: Not enough TRUSTEE signatures\\\\nConstraint: 1 STEWARD signature is required, Error: Not enough STEWARD signatures\\\\nConstraint: 1 ENDORSER signature is required, Error: Not enough ENDORSER signatures\',)","reqId":1572973235465445339,"op":"REJECT","identifier":"NcZhyokuNAL3iWdhC8uCqd"}'



As expected the previous procedure failed and we got back a response stating that the did used was not able to perform such an operation

**Could** we change the role of a deployed DID?


```python
# try to change the role of an already deployed did
nym_request = await ledger.build_nym_request(steward['did'], new_gov_did,
                                             new_gov_key, None, 'TRUST_ANCHOR')
await ledger.sign_and_submit_request(steward['pool'], steward['wallet'], steward['did'], nym_request)
```




    '{"reason":"client request invalid: UnauthorizedClientRequest(\'STEWARD can not touch verkey field since only the owner can modify it\',)","reqId":1572973236375267643,"identifier":"Th7MpTaRZVRYnPiabds81Y","op":"REJECT"}'



Apparently we can't change the role of a DID already registered into the ledger. Even if we use the agent that sent it to the ledger in the first place.

This conludes our discussion about establishing pairwise connection and registering newly created DIDs.

# Abstraction for onboarding

With **onboarding** we refer to the establishment of a pairwise connection between two parties (**from** and **to**)

Since onboarding is something we constantly have to perform to establish a secure channel between two parties, we are going to write a general procedure for it.

The important assumption, at least for how onboarding is thought here, is that the agent **from** has a did in her wallet that can send nym transactions to the ledger.

Furthermore, assume that all the sharing of the information out from the ledger is done throuhg a proper back channel.


To make things more clear we use **Alice** in place of **from** and **Bob** in place of **to**


```python
async def onboarding(Alice, Bob):
    # we assume that Alice can send nym transaction to the ledger
    # we use Alice as the "from account" and Bob as the "to account"

    # create ad-hoc dids for the connection

    # Alice creates a new did-key pair
    (Alice_did_for_Bob, Alice_key_for_Bob) = await did.create_and_store_my_did(Alice['wallet'], "{}")

    # Alice_did_for_Bob : Alice creates a did on purpose for Bob, she wants Bob to know her with this did
    # Alice_key_for_Bob: the verkey(e.g. PubKey) of the previous did

    # assuming Alice can send nym transaction, she register her new did in the ledger
    nym_request = await ledger.build_nym_request(Alice['did'],Alice_did_for_Bob, Alice_key_for_Bob, None, None)
    await ledger.sign_and_submit_request(Alice['pool'], Alice['wallet'], Alice['did'], nym_request)

    connection_request = {
        'did': Alice_did_for_Bob,
        'nonce': 123456789
    }

    # if Bob doesn't have a wallet for his did we create a new one
    if 'wallet' not in Bob:
        try:
            await wallet.create_wallet(Bob['wallet_config'], Bob['wallet_credentials'])
        except IndyError as ex:
            if ex.error_code == ErrorCode.PoolLedgerConfigAlreadyExistsError:
                pass
        Bob['wallet'] = await wallet.open_wallet(Bob['wallet_config'], Bob['wallet_credentials'])

    # we then create a did that Bob will use to connect with Alice
    (Bob_did_for_Alice, Bob_key_for_Alice) = await did.create_and_store_my_did(Bob['wallet'], "{}")

    # Bob asks the ledger for the verkey of the did Alice sent him in the connection request
    # this should be the same as Alice_key_for_Bob
    Alice_verkey_for_Bob = await did.key_for_did(Bob['pool'], Bob['wallet'], connection_request['did'])

    # Bob creates a response for Alice to solve the random challenge
    # Bob wants to say: Ehi Alice here are my did, my verkey and the secret you sent to me
    Bob['connection_response'] = json.dumps({
        'did': Bob_did_for_Alice,
        'verkey': Bob_key_for_Alice,
        'nonce': connection_request['nonce']
    })

    # Bob encrypts the response he wants to send to Alice
    # he uses the verkey of Alice that he got from the ledger
    Bob['anoncrypted_connection_response'] = \
        await crypto.anon_crypt(Alice_verkey_for_Bob, Bob['connection_response'].encode('utf-8'))

    # Alice receives the encrypted message
    Alice['anoncrypted_connection_response'] = Bob['anoncrypted_connection_response']

    # Alice decryptes the message
    Alice['connection_response'] = \
        json.loads((await crypto.anon_decrypt(Alice['wallet'], Alice_key_for_Bob,
                                              Alice['anoncrypted_connection_response'])).decode("utf-8"))

    # check that the random challenge is solved
    assert connection_request['nonce'] == Alice['connection_response']['nonce']

    # Alice sends the nym request to the ledger in order to register the did of Bob
    nym_request = await ledger.build_nym_request(Alice['did'],Bob_did_for_Alice, Bob_key_for_Alice, None, None)
    await ledger.sign_and_submit_request(Alice['pool'], Alice['wallet'], Alice['did'], nym_request)

    return Alice_did_for_Bob, Alice_key_for_Bob, Bob_did_for_Alice, Bob_key_for_Alice, Bob['connection_response']


```

# Credential Schemas and Definitions

This section focuses on two other main concepts of the Indy Hyperledger ecosystem. Namely the **Credential Schema and Definition**.

Both the Schema and the Definition are necessary for the issuing of the credential to an Indy agent.

## Credential Schema

A **Credential Schema** is the semantic structure that describes which particular attributes a Credential could possess.

Schemas can be stored into the Ledger by users registered into the ledger with the role of TAs.

A Credential Schema can be thought as a guideline for Credential Definition that will be built on top of it.

In our example the Government produces credential schemas referring to the object **Transcript**. Then any college in the Government jurisdiction will use such a schema as a directive to build their own idea of **Transcript**.

We say in this case that the Government **sets the semantic basis**.



```python
# government creates a schema for the credential transcript. It sets the semantics basis
transcript = {
    'name': 'Transcript',
    'version': '1.2',
    'attributes': ['first_name', 'last_name', 'degree', 'status', 'year', 'average', 'ssn']
}
(government['transcript_schema_id'], government['transcript_schema']) = \
    await anoncreds.issuer_create_schema(government['did'], transcript['name'], transcript['version'],
                                         json.dumps(transcript['attributes']))
transcript_schema_id = government['transcript_schema_id']
```


```python
# build the schema request and send it to the ledger
schema_request = await ledger.build_schema_request(government['did'], government['transcript_schema'])
await ledger.sign_and_submit_request(government['pool'], government['wallet'], government['did'], schema_request)
```




    '{"result":{"txnMetadata":{"txnId":"ABS4UwqvF84EG9h3B6HeL2:2:Transcript:1.2","seqNo":16,"txnTime":1572973238},"txn":{"protocolVersion":2,"type":"101","metadata":{"reqId":1572973237452873151,"from":"ABS4UwqvF84EG9h3B6HeL2","payloadDigest":"b44f88c0fa1ec3030978aa6803277bb73b4600cbebb3015d04c07fe47eb0799f","digest":"68c99aed867e7d1c54ea2ae3fff598ebcc12ffb86c691eb4b54bd4eb2c207763"},"data":{"data":{"name":"Transcript","version":"1.2","attr_names":["first_name","ssn","year","last_name","degree","status","average"]}}},"reqSignature":{"type":"ED25519","values":[{"from":"ABS4UwqvF84EG9h3B6HeL2","value":"4CPZpbkGcFnSt4w23njVB5Zpopqsn38mBxLL73nLWQuf7bxkC9opwMicWT44mK14TcFUJPMNnCig4iEUUZHMdGeb"}]},"auditPath":["E8da3k5eRzCjZgJSYTizioy9APRofCoptwBUKbgabAQt","9zmbvC1YzTxdDs89C58pvUinq69MPESkYXsrre6iz8HR","G75enhk9vZ7xu7TAKcMWy7LhxZjvpLhifGb1DkEnxyzc","DNHM372JZJoGcxdHdmsj3QSSiomyeZux6ssJXxAJqyvd"],"rootHash":"H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs","ver":"1"},"op":"REPLY"}'



The Government creates also the schema for a Job Certificate. This will be the semantic basis for the Credential Job Certificate that will be issued by an other agent, the Acme corporation.


```python
# in the same way the govt sends a schema definition to the ledger for the Job Certificate
job_certificate = {
    'name': 'Job-Certificate',
    'version': '0.2',
    'attributes': ['first_name', 'last_name', 'salary', 'employee_status', 'experience']
}
(government['job_certificate_schema_id'], government['job_certificate_schema']) = \
    await anoncreds.issuer_create_schema(government['did'], job_certificate['name'], job_certificate['version'],
                                         json.dumps(job_certificate['attributes']))
job_certificate_schema_id = government['job_certificate_schema_id']

schema_request = await ledger.build_schema_request(government['did'], government['job_certificate_schema'])
await ledger.sign_and_submit_request(government['pool'], government['wallet'], government['did'], schema_request)
```




    '{"result":{"txnMetadata":{"txnId":"ABS4UwqvF84EG9h3B6HeL2:2:Job-Certificate:0.2","seqNo":17,"txnTime":1572973239},"txn":{"protocolVersion":2,"type":"101","metadata":{"reqId":1572973238486938504,"from":"ABS4UwqvF84EG9h3B6HeL2","payloadDigest":"ad6849402f6eb6be205e897c5c99a159d831f7ccc90028c94d38e1bc4923cf91","digest":"bf7ebc89991ba318ab3671d0ad17afda2680b4fa124a4a29336658461c94b483"},"data":{"data":{"name":"Job-Certificate","version":"0.2","attr_names":["first_name","last_name","experience","salary","employee_status"]}}},"reqSignature":{"type":"ED25519","values":[{"from":"ABS4UwqvF84EG9h3B6HeL2","value":"XnfFMVNtFKoGPukGVhwT4gAp18aTD8CgywriezaxuVY6tNAVProA88fTHbHjfcnV7j7Z8xVjs718Hs7J4Rfbx6y"}]},"auditPath":["H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs"],"rootHash":"X2XAdmUdG38oCpXNe9RVGVkC6pTiuYCn5mY18jFGbpb","ver":"1"},"op":"REPLY"}'



## Credential Definition

On top of the Credential Schemas built in the previous steps, the agents will create Credential Definitions consistent with the set semantic basis.

### Faber College creates a CD for Transcript

Using the credential schemas issued by the Government, Faber college creates a Credential Definition for its transcript.

**Note that both credential schemas and definitions can't be updated once deployed. In that case new ones need to be published into the ledger**


```python
# Let's first of all create a wallet for Faber and save one of its did as TA
faber = {
  'name': "Faber College",
  'wallet_config': json.dumps({'id': 'faber_wallet'}),
  'wallet_credentials': json.dumps({'key': 'faber_wallet_key'}),
  'pool': pool_handle,
  'seed': '000000000000000000000000Faber001'
}
await wallet.create_wallet(faber['wallet_config'], faber['wallet_credentials'])
faber['wallet'] = await wallet.open_wallet(faber['wallet_config'], faber['wallet_credentials'])

```


```python
faber['did'], faber['key'] = await did.create_and_store_my_did(faber['wallet'],json.dumps({'seed':faber['seed']}))
```

We assume here that the Steward has done all the identity checks on Faber (using adhoc DIDs) in the same way she DID previously for the Government in the section about Users and dids.


```python
# the Steward sends the nym transaction to the ledger to assign the role of TA to faber['did']
nym_request = await ledger.build_nym_request(steward['did'],faber['did'],faber['key'],None,'TRUST_ANCHOR')
await ledger.sign_and_submit_request(steward['pool'],steward['wallet'],steward['did'],nym_request)
```




    '{"result":{"reqSignature":{"type":"ED25519","values":[{"from":"Th7MpTaRZVRYnPiabds81Y","value":"4yCmztnYbDaqqHfAqtLXoUfmtbGUYJ2AX6UcJFBPQE2NmabwAQsBpT2o3Q9seqs47NnNXg7XxPxJ9J1oXV6xDKJr"}]},"txn":{"data":{"verkey":"9dkoHAZNaudzBmAj3VL1ctV7pHXTQLhRksVaYxsGjb4L","dest":"Gqm3qg342RFovaL5U1rT1W","role":"101"},"metadata":{"reqId":1572973241507195187,"from":"Th7MpTaRZVRYnPiabds81Y","digest":"dcb6c6b90aaf9d10d3e00ecd9b492aaa6297e85eccd125564179c75d23b044c7","payloadDigest":"821508e8f05a40002c370d316d3207f4b5aa1256ba35e514e5fd6f578126a102"},"type":"1","protocolVersion":2},"ver":"1","txnMetadata":{"txnId":"e8f0ada38d0f4dedc15266218f40015b12c1d530b7e4dfc0a06609dd94b3b2b9","seqNo":18,"txnTime":1572973241},"rootHash":"DFZ9Kr1Nr8y5mNEdFdUpzwnL6FY1qo7nkLL4GNxePSAv","auditPath":["Dp9LgeEMBUUTNPeoAzzWxG3JNpMCfLcTnVJ47F2k6gwQ","H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs"]},"op":"REPLY"}'



To build a definition for Transcript, Faber gets the schema from the ledger.

To retrieve the schema from the ledger Faber uses a pattern that will recur whenever an agent desire to get information from the ledger

The steps are the following:
    - build the "get request"
    - submit the request -> get a response from the ledger
    - parse the response using the procedure relevant to the object requested  


Therefore with the following Faber will get the schema from the ledger


```python
# get the schema from the ledger
get_schema_request = await ledger.build_get_schema_request(faber['did'], transcript_schema_id)
get_schema_response = await ledger.submit_request(faber['pool'], get_schema_request)
faber['transcript_schema_id'], faber['transcript_schema'] = await ledger.parse_get_schema_response(get_schema_response)
```

The transcript_schema_id has the following structure:
"identifier"(who deployed it):"protocolVersion":"data.name":"version"


```python
faber['transcript_schema']
```




    '{"ver":"1.0","id":"ABS4UwqvF84EG9h3B6HeL2:2:Transcript:1.2","name":"Transcript","version":"1.2","attrNames":["last_name","status","average","first_name","degree","ssn","year"],"seqNo":16}'



Just note that such a schema differ from the one being deployed by the Government by just the "seqNo". This refers to the transaction sequence number. When the quantity is not retrieved from the ledger, this will be null, as shown in the following cell


```python
government['transcript_schema']
```




    '{"ver":"1.0","id":"ABS4UwqvF84EG9h3B6HeL2:2:Transcript:1.2","name":"Transcript","version":"1.2","attrNames":["ssn","degree","last_name","first_name","status","year","average"],"seqNo":null}'



We can see that Faber has retrieved successfully the schema from the ledger comparing the schema_id it got with what the Government sent


```python
faber['transcript_schema_id'] == government['transcript_schema_id']
```




    True



Using the schema retrieved above, Faber creates a Credential Definition.

Credential definitions have two parts: private and public. The public one is shared on the ledger, the other is kept private in the wallet of the issuer.


```python
# Faber creates and send the credential definition
transcript_cred_def = {
    'tag': 'TAG1',
    'type': 'CL',
    'config': {"support_revocation": False}
}
(faber['transcript_cred_def_id'], faber['transcript_cred_def']) = \
    await anoncreds.issuer_create_and_store_credential_def(faber['wallet'], faber['did'],
                                                           faber['transcript_schema'], transcript_cred_def['tag'],
                                                           transcript_cred_def['type'],
                                                           json.dumps(transcript_cred_def['config']))
```


```python
# send the request to the ledger
cred_def_request = await ledger.build_cred_def_request(faber['did'], faber['transcript_cred_def'])
receipt = await ledger.sign_and_submit_request(faber['pool'], faber['wallet'], faber['did'], cred_def_request)
```

Faber used here a pattern that we will see frequently whenever a new object needs to be sent to the ledger

This can be summarized as the following:
    - create (and store in this case) an object to be sent to the ledger
    - build a request wrapping the object just created
    - sign and submit the request to the ledger


### Acme corporation creates a CD for Job-Certificate  (revocable certificates)

With respect to the previous CD that was not revocable, this one should allow for such an occurrence.

We firstly need to create a Acme profile and register a DID for it with the role of TA.


```python
# create a did for ACME and register it as TA into the ledger
acme = {
  'name': "Acme",
  'wallet_config': json.dumps({'id': 'acme_wallet'}),
  'wallet_credentials': json.dumps({'key': 'acme_wallet_key'}),
  'pool': pool_handle,
  'seed': '000000000000000000000000Acme0001'
}
await wallet.create_wallet(acme['wallet_config'], acme['wallet_credentials'])
acme['wallet'] = await wallet.open_wallet(acme['wallet_config'], acme['wallet_credentials'])
acme['did'], acme['key'] = await did.create_and_store_my_did(acme['wallet'],json.dumps({'seed':acme['seed']}))
```

Be careful when we set the seed. If we have already sent a transaction to the ledger if we try to register again the did, we need to restart the ledger. It is, indeed, not sufficient to clear just the local history.
If we are running the pool with the Docker container, it means restarting the process.

This is just our suggestion in testing stage. Instead of setting the seed we could have just created a random DID by not passing the seed argument.


```python
just_an_other_did_for_acme, just_an_other_key_for_acme = await did.create_and_store_my_did(acme['wallet'],'{}')
```

We assume here that the DID stored in the Acme dictionary is the one to be sent to the ledger with the role of TA. Furthermore we assume that the Steward got such a DID in a cryptographically secure way. That is after a successful onboarding, as Faber did with the Steward.


```python
nym_request = await ledger.build_nym_request(steward['did'],acme['did'],acme['key'],None,'TRUST_ANCHOR')
await ledger.sign_and_submit_request(steward['pool'],steward['wallet'],steward['did'],nym_request)
```




    '{"result":{"txnMetadata":{"txnId":"7a95db3d0b638ab886945dd88fa08288c340fd4298d7762c314bb595c0fdab14","seqNo":20,"txnTime":1572973246},"txn":{"protocolVersion":2,"type":"1","metadata":{"reqId":1572973246314441098,"from":"Th7MpTaRZVRYnPiabds81Y","payloadDigest":"3fef7e33dfea189305e92a4c36d8faecd30285d0dadb4dbf7029901e1446e856","digest":"50fc7026508b11cb782b4af7350a6aed96025b8536bf23a356a96293ee782f55"},"data":{"verkey":"5CDkAY23izGYWHK8oeHBgbGESpxjndMyiZVZyRD3oUyc","role":"101","dest":"8hFKa2Xos6A7EPT2SC3edb"}},"reqSignature":{"type":"ED25519","values":[{"from":"Th7MpTaRZVRYnPiabds81Y","value":"yjCiZrTqwrMdg1PktDUc6QmhEsAK935c7TjRhimRyzkoB2EgAxyLTPurZdLU5k9eUJAuLztgHBV72iWg3QoNCTK"}]},"auditPath":["J2mw1NQu2WJLp8EZP3dk6KULgA8fZECV1j4zotzpMGZs","27omkoCnmjqBDrLeUsjfsVy5YLrmXsM4ArxMghs5KuuN","H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs"],"rootHash":"Ewh6iiCGkyp8i1amCh4ZDgs4XDS81QDNNBAAmeif8vJC","ver":"1"},"op":"REPLY"}'



Acme retrieves the schema for Job Application from the ledger


```python
get_schema_request = await ledger.build_get_schema_request(acme['did'], job_certificate_schema_id)
get_schema_response = await ledger.submit_request(acme['pool'], get_schema_request)
acme['job_certificate_schema_id'], acme['job_certificate_schema'] = await ledger.parse_get_schema_response(get_schema_response)

```

We show that is the same that the Government deployed to the ledger


```python
acme['job_certificate_schema_id'] == government['job_certificate_schema_id']
```




    True



Acme creates a credential definition on top of that schema and sends it to the ledger


```python
job_certificate_cred_def = {
  'tag': 'TAG1',
  'type': 'CL',
  'config': {"support_revocation": True}
}
(acme['job_certificate_cred_def_id'], acme['job_certificate_cred_def']) = \
  await anoncreds.issuer_create_and_store_credential_def(acme['wallet'], acme['did'],
                                                         acme['job_certificate_schema'], job_certificate_cred_def['tag'],
                                                         job_certificate_cred_def['type'],
                                                         json.dumps(job_certificate_cred_def['config']))

cred_def_request = await ledger.build_cred_def_request(acme['did'], acme['job_certificate_cred_def'])
receipt = await ledger.sign_and_submit_request(acme['pool'], acme['wallet'], acme['did'], cred_def_request)
```

With respect to the previous case concerning the transcript, here the credential can be revoked.

Therefore a revocation registry needs to be created in order to keep track of the accumulator values. We invite the reader to check the official documentation for what concerns the cryptography techniques used here.

This notwithstanding, we want to give a rough idea to the reader.

A credential takes part in the computation of an accumulator. The accumulator depends on the credentials in the same way a natural number depends on a product of primes. Indeed a natural number can be decomposed as the product of one and only one set of prime numbers.

Just think of a credential as a prime for the sake of our argument. If we know the accumulator value and the product of all the prime numbers except ours, we can prove that our number can be used with the other to get the accumulator. Therefore we prove that we have such a credential that allows us to compute the accumulator. In other words, we have the right number to complete the product and get the original natural number.

**Revocation Registry**

It is duty of the issuer to create the registry and sent it to the ledger.


```python
from indy import blob_storage
```


```python
# acme creates a revocation registry
from pathlib import Path

acme['tails_writer_config'] = json.dumps({'base_dir': str(Path.home().joinpath('.indy_client').joinpath("tails")), 'uri_pattern': ''})
acme['tails_writer'] = await blob_storage.open_writer('default', acme['tails_writer_config'])

```


```python
revoc_reg_def_data = {
    'tag': 'cred_def_tag',
    'config': json.dumps({"max_cred_num": 5, 'issuance_type': 'ISSUANCE_ON_DEMAND'})
}
```


```python
(acme['revoc_reg_id'], acme['revoc_reg_def'], acme['revoc_reg_entry']) = \
        await anoncreds.issuer_create_and_store_revoc_reg(acme['wallet'], acme['did'], 'CL_ACCUM',
                                                          revoc_reg_def_data['tag'],
                                                          acme['job_certificate_cred_def_id'],
                                                          revoc_reg_def_data['config'],
                                                          acme['tails_writer'])
```

From the previous we got:
    - revoc_reg_id: identifier of created revocation registry definition
    - revoc_reg_def: public part of revocation registry definition (json)
    - revoc_reg_entry: revocation registry entry that defines initial state of revocation registry (json)


```python
# build a request for revocation reg definition, Send it to the ledger
# this adds a REVOC_REG_DEF to an exixting credential definition
acme['revoc_reg_def_request'] = await ledger.build_revoc_reg_def_request(acme['did'], acme['revoc_reg_def'])
await ledger.sign_and_submit_request(acme['pool'], acme['wallet'], acme['did'], acme['revoc_reg_def_request'])

```




    '{"result":{"reqSignature":{"type":"ED25519","values":[{"from":"8hFKa2Xos6A7EPT2SC3edb","value":"5u6CcGvL2TFeQZNdCoa1x4KarCwxB3JcisFNAy7DFi3C9tJ14SC9sLnGrBSAq9S8irdkuMByJYjuoBnrTmPuhRVK"}]},"txn":{"data":{"tag":"cred_def_tag","credDefId":"8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1","value":{"tailsLocation":"\\/root\\/.indy_client\\/tails\\/7iDLRaoXFPH4tpWv67Vp872vwFkKaMfvTP7PaZnyFSdn","maxCredNum":5,"tailsHash":"7iDLRaoXFPH4tpWv67Vp872vwFkKaMfvTP7PaZnyFSdn","issuanceType":"ISSUANCE_ON_DEMAND","publicKeys":{"accumKey":{"z":"1 1D81FBB4FBEB35AB3007875255606F4A922EDD0385306A689032B84D51F53446 1 14C45A8A7568C3D826645512E5AFA912445EB3AEDCA28179869522591A904611 1 16E154DF6EDF5991064B103122B5D25602F21D2DFC9B6F5C71EA315613CD1B1B 1 10B9167E5868358AA501ED62F9E7CE61EE79E62142731B40AE1B3E81B4EB07AF 1 01B4A7EDE7616E6FFE1D5FB295A5DAFC11966AF1408B296D108581E721EC28FE 1 1FDBAA6CDBFBCB6BCC456900675745FEE69B79D6A8BBFD20E1E56FC363BAFE22 1 001408FF2D7DDA1E4BFE26585496E7ED54CD5F14C9D8F7A9514D4EAD9727D9A0 1 15E7741FF555C41C4BFBE05145FDB4622B873594CF983FD6762318B0B39D0B60 1 0A79533EA65B160021E89C7B12CE959836BFA2C51B8938B68485CA1B062DF64A 1 150D71178EFF3A75D186D634600C644454E0B337EF211CE378F111F1915E56D5 1 21F4B8390558A197CF5B3082F6485879B1C98A157F3DD20C24B295915334AE42 1 0F0C512764D1BC4D100ECDAF6A94A030BAFE0CB267A17922A8731BFA3826C498"}}},"id":"8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag","revocDefType":"CL_ACCUM"},"metadata":{"reqId":1572973256917467406,"from":"8hFKa2Xos6A7EPT2SC3edb","digest":"107333d5a7e31a7c1fb7fdd985debc4119f92957e2acaf8b6f6f8ab725a98cc1","payloadDigest":"d41f8105e35dbfa7780a84e66ea0d39cd04a07051df2e244fb4ae5ab65207d6a"},"type":"113","protocolVersion":2},"ver":"1","txnMetadata":{"txnId":"8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag","seqNo":22,"txnTime":1572973257},"rootHash":"HCY4JEDVW5vrQWqx5zJsi3DpfbL4CiWo45JVXvkGytN4","auditPath":["Acd1rEPUKXZ5PzqFwtEMtguh2MSqQdF4K5HcqxfDzV81","7z24RR4TUUHGwJHbv5Ho11CrtdQpNST29Ri2dVb8o681","H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs"]},"op":"REPLY"}'



In this case, being the first transaction to the ledger, the revocation registry entry that we previously got will be used for the initial value of the accumulator.


```python
# Request to add the RevocReg entry containing the new accumulator value and issued/revoked indices
acme['revoc_reg_entry_request'] = \
    await ledger.build_revoc_reg_entry_request(acme['did'], acme['revoc_reg_id'], 'CL_ACCUM',
                                               acme['revoc_reg_entry'])
await ledger.sign_and_submit_request(acme['pool'], acme['wallet'], acme['did'], acme['revoc_reg_entry_request'])
```




    '{"result":{"reqSignature":{"type":"ED25519","values":[{"from":"8hFKa2Xos6A7EPT2SC3edb","value":"2MYTuDVrUnBJHJLMmVksbc56oGnpMdu5PdpnmCcPiaTvLFfbwqQiNiZSzuzMNpDhzLUdhJjfUtKfBgsvVkiF3f1g"}]},"txn":{"data":{"value":{"accum":"1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000 2 095E45DDF417D05FB10933FFC63D474548B7FFFF7888802F07FFFFFF7D07A8A8 1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000"},"revocDefType":"CL_ACCUM","revocRegDefId":"8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag"},"metadata":{"reqId":1572973257937694701,"from":"8hFKa2Xos6A7EPT2SC3edb","digest":"7e9c051f93e187333ad344d285c7272b46e335f82def49ef459f1a3a0af176b7","payloadDigest":"5347c463730466dc3e818a649b9fa5217659157793b140d81ed12b5942208669"},"type":"114","protocolVersion":2},"ver":"1","txnMetadata":{"txnId":"5:8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag","seqNo":23,"txnTime":1572973258},"rootHash":"8QxUHKWmmRXmYrNtBr3qX5H5c893jzEbdN5Bh9QwsJME","auditPath":["DhfTMvqGv29Dgp52jdVENDDG6FxsuUegrqhb1KcLhnE","7z24RR4TUUHGwJHbv5Ho11CrtdQpNST29Ri2dVb8o681","H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs"]},"op":"REPLY"}'



# Alice asks for credentials

<a id='alice_gets_transcript'></a>
## Alice gets a Transcript credential from Faber College

Alice asks for a transcript to Faber college.
Faber, after having established a connection with Alice, will issue such a credential

The process is the following:

1) Faber: (credential offer)--> Alice

2) Alice retrieves the (credential schema) and the (credential definition) from the ledger

3) Alice: (credential request)--> Faber

4) Faber builds transcript credential for Alice

5) Alice stores transcript credential in her wallet

First of all we create a wallet for Alice


```python
# create Alice wallet and did
alice = {
    'name': 'Alice',
    'wallet_config': json.dumps({'id': 'alice_wallet'}),
    'wallet_credentials': json.dumps({'key': 'alice_wallet_key'}),
    'pool': pool_handle
}
await wallet.create_wallet(alice['wallet_config'], alice['wallet_credentials'])
alice['wallet'] = await wallet.open_wallet(alice['wallet_config'], alice['wallet_credentials'])
```

Using the onboarding procedure we establish a pairwise connection between Alice and Faber


```python
faber_did_for_alice,faber_key_for_alice, \
alice_did_for_faber, alice_key_for_faber,\
connection_response_alice_to_faber = await onboarding(faber,alice)
```

Faber needs to create a credential offering using the credential definition of the transcript


```python
 faber['transcript_cred_offer'] = await anoncreds.issuer_create_credential_offer(faber['wallet'], faber['transcript_cred_def_id'])
```

Faber has created in this way a Credential Offering that is going to be sent to Alice

The exchange of the information is done using **authenticated encryption** as previously seen


```python
# Faber retrieves the verkey of Alice's known did
key_of_alice_did_know_to_faber = await did.key_for_did(faber['pool'],faber['wallet'],alice_did_for_faber)
```


```python
# expected to be True, since Faber gets back the key of the did that Alice decided to use in their pairwise connection
key_of_alice_did_know_to_faber == alice_key_for_faber
```




    True




```python
faber['authcrypted_transcript_cred_offer'] = await crypto.auth_crypt(faber['wallet'],\
                                                                    faber_key_for_alice,
                                                                    key_of_alice_did_know_to_faber,
                                                                    faber['transcript_cred_offer'].encode("utf-8"))
```

Faber sends the encrypted message to Alice


```python
alice['authcrypted_transcript_cred_offer'] = faber['authcrypted_transcript_cred_offer']
```


```python
# Alice decrypts it
_,encoded_transcript_offer = await crypto.auth_decrypt(alice['wallet'],alice_key_for_faber,alice['authcrypted_transcript_cred_offer'])
```


```python
alice['transcript_cred_offer'] = encoded_transcript_offer.decode("utf-8")
```


```python
# check that Alice got the original message without tampering
assert alice['transcript_cred_offer'] == faber['transcript_cred_offer']
```

Alice wants to check what data the Transcript contains

She needs the the schema id that can be retrieved from the data she got from Faber


```python
schema_id = json.loads(alice['transcript_cred_offer'])['schema_id']
```


```python
get_schema_request = await ledger.build_get_schema_request(alice_did_for_faber, schema_id)
get_schema_response = await ledger.submit_request(alice['pool'], get_schema_request)
transcript_id, transcript_schema = await ledger.parse_get_schema_response(get_schema_response)

```

Got the schema from the ledger, she can then see what attributes constitute the schema


```python
print(transcript_schema)
```

    {"ver":"1.0","id":"ABS4UwqvF84EG9h3B6HeL2:2:Transcript:1.2","name":"Transcript","version":"1.2","attrNames":["ssn","status","first_name","last_name","degree","average","year"],"seqNo":16}


But this is just the schema of the Transcript. Alice knows just what kind of data will go inside, but now she wants the actual credential.

In order to do that she has to create a Master Secret.

This is a secret privately known to her and used to prove that the claims in the credential apply only to her.

Furthermore the Master Secret allows the Prover to prove that she has all the credentials she claims.



```python
alice['master_secret_id'] = await anoncreds.prover_create_master_secret(alice['wallet'], None)
```

Before sending the Credential Request, Alice needs to get also the Credential Definition.

Therefore Alice needs both the Credential Schema and the Credential Definition in order to ask for a Credential Request


```python
cred_def_id = json.loads(alice['transcript_cred_offer'])['cred_def_id']
```


```python
get_cred_def_request = await ledger.build_get_cred_def_request(alice_did_for_faber,cred_def_id )
get_cred_def_response = await ledger.submit_request(alice['pool'], get_cred_def_request)
alice['transcript_cred_def_id'], alice['transcript_cred_def'] = await ledger.parse_get_cred_def_response(get_cred_def_response)
```

As we can see the pattern is always the same: build object -> submit request -> parse response

Alice creates a Credential Request(CR) using the Transcript (cred. schema and definition) and her master secret

Alice says: Faber I signed this with my master secret. I want a transcript based on these credentials(schema and definition)


```python
(alice['transcript_cred_request'], alice['transcript_cred_request_metadata']) = \
    await anoncreds.prover_create_credential_req(alice['wallet'], alice_did_for_faber, alice['transcript_cred_offer'],
                                                 alice['transcript_cred_def'], alice['master_secret_id'])
```


```python
# We can see how Alice gets the role of the prover. Her did is indeed the value of "prover_did" key
alice_did_for_faber == json.loads(alice['transcript_cred_request'])['prover_did']
```




    True



Alice sends this request to Faber


```python
alice['authcrypted_transcript_cred_request'] = await crypto.auth_crypt(alice['wallet'],\
                                                                alice_key_for_faber,
                                                                faber_key_for_alice,
                                                                alice['transcript_cred_request'].encode("utf-8"))
```


```python
# Faber receives the encrypted message
faber['authcrypted_transcript_cred_request'] = alice['authcrypted_transcript_cred_request']
```


```python
_ , encoded_transcript_request = await crypto.auth_decrypt(faber['wallet'],faber_key_for_alice,\
                                                faber['authcrypted_transcript_cred_request'])
```


```python
faber['transcript_cred_request'] = encoded_transcript_request.decode("utf-8")
```


```python
# check no tapering
assert faber['transcript_cred_request'] == alice['transcript_cred_request']
```

Faber can now build the Transcript credential with Alice data


```python
transcript_cred_values = json.dumps({
  "first_name": {"raw": "Alice", "encoded": "1139481716457488690172217916278103335"},
  "last_name": {"raw": "Garcia", "encoded": "5321642780241790123587902456789123452"},
  "degree": {"raw": "Bachelor of Science, Marketing", "encoded": "12434523576212321"},
  "status": {"raw": "graduated", "encoded": "2213454313412354"},
  "ssn": {"raw": "123-45-6789", "encoded": "3124141231422543541"},
  "year": {"raw": "2015", "encoded": "2015"},
  "average": {"raw": "5", "encoded": "5"}
})

# faber['transcript_cred_offer'] -> created by Faber and sent to Alice
# faber['transcript_cred_request'] -> after offer received, created by Alice and sent to Faber
# then Faber combines the offer and the request with the credential values provided in order to issue the credential
faber['transcript_cred'], _, _ = \
  await anoncreds.issuer_create_credential(faber['wallet'], faber['transcript_cred_offer'], faber['transcript_cred_request'],
                                           transcript_cred_values, None, None)
```

Store the credential in the wallet


```python
# assume encrypted exchange here as done in previous steps
alice['transcript_cred'] = faber['transcript_cred']
```


```python
# alice['transcript_cred'] : full credentials received from Faber
await anoncreds.prover_store_credential(alice['wallet'], None, alice['transcript_cred_request_metadata'], alice['transcript_cred'],
                                        alice['transcript_cred_def'], None)
```




    '5117472d-5e6c-4748-a346-71d5517903f2'



The previous returns a referent id that locates the credential stored in the wallet

<a id='alice_job'></a>
# Alice applies for a job

An important take-away from this chapter is how Alice can prove the validity of her Transcript

Establish a connection channel Alice <-> Acme using the onboarding procedure


```python
acme['did_for_alice'], acme['key_for_alice'],alice['did_for_acme'], alice['key_for_acme'], \
    acme['alice_connection_response'] = await onboarding(acme, alice)
```


```python
acme['did_for_alice']
```




    'VZQxD1dhJfMc9hW4MHuiPG'



Job-Application Proof Request (sent to Alice by Acme).

Request in the sense that the verifier (Acme) asks the prover (Alice) to provide predicates to be checked in their validity.

Acme says: "Ehy Alice please fill the Job Application in this way and show me that your grades are above the requested average"

In the Proof Request Acme specifies which fields need to be provided, what restrictions (e.g. Transcript only from Faber) and which ones need to be proved.


```python
json.dumps({
    'nonce': '1432422343242122312411212',
      'name': 'Job-Application',
      'version': '0.1',
      'requested_attributes': {
          'attr1_referent': {
              'name': 'first_name'
          }}})

```




    '{"requested_attributes": {"attr1_referent": {"name": "first_name"}}, "name": "Job-Application", "nonce": "1432422343242122312411212", "version": "0.1"}'




```python

```


```python
# proof request from Acme
acme['job_application_proof_request'] = json.dumps({
      'nonce': '1432422343242122312411212',
      'name': 'Job-Application',
      'version': '0.1',
      'requested_attributes': {
          'attr1_referent': {
              'name': 'first_name'
          },
          'attr2_referent': {
              'name': 'last_name'
          },
          'attr3_referent': {
              'name': 'degree',
              'restrictions': [{'cred_def_id': faber['transcript_cred_def_id']}]
          },
          'attr4_referent': {
              'name': 'status',
              'restrictions': [{'cred_def_id': faber['transcript_cred_def_id']}]
          },
          'attr5_referent': {
              'name': 'ssn',
              'restrictions': [{'cred_def_id': faber['transcript_cred_def_id']}]
          },
          'attr6_referent': {
              'name': 'phone_number'
          }
      },
      'requested_predicates': {
          'predicate1_referent': {
              'name': 'average',
              'p_type': '>=',
              'p_value': 4,
              'restrictions': [{'cred_def_id': faber['transcript_cred_def_id']}]
          }
      }
  })
```

We see that in the proof request Acme has specified:
    - requested attributes:
        - without a reference credential (Alice will self assert them)
        - with a mandatory reference credential (Issued by a valid agent)
    - requested predicates (proof statements)



```python
# Acme will use this key to encrypt messages to Alice
acme['alice_key_for_acme'] = \
    await did.key_for_did(acme['pool'], acme['wallet'], json.loads(acme['alice_connection_response'])['did'])


```


```python
acme['authcrypted_job_application_proof_request'] = \
    await crypto.auth_crypt(acme['wallet'], acme['key_for_alice'], acme['alice_key_for_acme'],
                            acme['job_application_proof_request'].encode('utf-8'))
```


```python
alice['authcrypted_job_application_proof_request'] = acme['authcrypted_job_application_proof_request']


```


```python
alice['acme_key_for_alice'], alice['job_application_proof_request_encoded'] = \
await crypto.auth_decrypt(alice['wallet'], alice['key_for_acme'],\
                           alice['authcrypted_job_application_proof_request'])
```


```python
alice['job_application_proof_request'] = alice['job_application_proof_request_encoded'].decode("utf-8")
```

Alice got a Job Application proof request from Acme


```python
alice['job_application_proof_request']
```




    '{"requested_attributes": {"attr3_referent": {"name": "degree", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}]}, "attr2_referent": {"name": "last_name"}, "attr1_referent": {"name": "first_name"}, "attr4_referent": {"name": "status", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}]}, "attr5_referent": {"name": "ssn", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}]}, "attr6_referent": {"name": "phone_number"}}, "name": "Job-Application", "nonce": "1432422343242122312411212", "version": "0.1", "requested_predicates": {"predicate1_referent": {"p_type": ">=", "name": "average", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}], "p_value": 4}}}'



Now she can process it and send the necessary material to Acme


```python
# Search for credentials matching the given proof request.
# Instead of immediately returning of fetched credentials this call returns search_handle that can be used later
# to fetch records by small batches (with prover_fetch_credentials_for_proof_req).

search_for_job_application_proof_request = \
    await anoncreds.prover_search_credentials_for_proof_req(alice['wallet'],
                                                            alice['job_application_proof_request'], None)

```


```python
# it returns a search handle that will be fetched on request
search_for_job_application_proof_request
```




    59




```python
# this procedure gets the search handle and a given referent requested by Acme returns credential information
# it is important to look at how the results are fetched
async def get_credential_for_referent(search_handle, referent):
    credentials = json.loads(
        await anoncreds.prover_fetch_credentials_for_proof_req(search_handle, referent, 10))
    return credentials[0]['cred_info']
```


```python
# fetch the attributes requested by Acme and create the relative credential
cred_for_attr1 = await get_credential_for_referent(search_for_job_application_proof_request, 'attr1_referent')
cred_for_attr2 = await get_credential_for_referent(search_for_job_application_proof_request, 'attr2_referent')
cred_for_attr3 = await get_credential_for_referent(search_for_job_application_proof_request, 'attr3_referent')
cred_for_attr4 = await get_credential_for_referent(search_for_job_application_proof_request, 'attr4_referent')
cred_for_attr5 = await get_credential_for_referent(search_for_job_application_proof_request, 'attr5_referent')
cred_for_predicate1 = \
    await get_credential_for_referent(search_for_job_application_proof_request, 'predicate1_referent')

```


```python
# let's look inside one of them
cred_for_attr1
```




    {'attrs': {'average': '5',
      'degree': 'Bachelor of Science, Marketing',
      'first_name': 'Alice',
      'last_name': 'Garcia',
      'ssn': '123-45-6789',
      'status': 'graduated',
      'year': '2015'},
     'cred_def_id': 'Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1',
     'cred_rev_id': None,
     'referent': '5117472d-5e6c-4748-a346-71d5517903f2',
     'rev_reg_id': None,
     'schema_id': 'ABS4UwqvF84EG9h3B6HeL2:2:Transcript:1.2'}



We see that there is information relevant to Alice that she can send to Acme in order to prove its Job-Application request


```python
# after the relevant data are retreived we can close the search handle
await anoncreds.prover_close_credentials_search_for_proof_req(search_for_job_application_proof_request)
```


```python
# prepare the credentials to fill the application
alice['creds_for_job_application_proof'] = {cred_for_attr1['referent']: cred_for_attr1,
                                                cred_for_attr2['referent']: cred_for_attr2,
                                                cred_for_attr3['referent']: cred_for_attr3,
                                                cred_for_attr4['referent']: cred_for_attr4,
                                                cred_for_attr5['referent']: cred_for_attr5,
                                                cred_for_predicate1['referent']: cred_for_predicate1}

```


```python
alice['creds_for_job_application_proof']
```




    {'5117472d-5e6c-4748-a346-71d5517903f2': {'attrs': {'average': '5',
       'degree': 'Bachelor of Science, Marketing',
       'first_name': 'Alice',
       'last_name': 'Garcia',
       'ssn': '123-45-6789',
       'status': 'graduated',
       'year': '2015'},
      'cred_def_id': 'Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1',
      'cred_rev_id': None,
      'referent': '5117472d-5e6c-4748-a346-71d5517903f2',
      'rev_reg_id': None,
      'schema_id': 'ABS4UwqvF84EG9h3B6HeL2:2:Transcript:1.2'}}



In order to compute the proof we need the schemas and the definitions of the credentials concerning the prover

This is to say that Alice is presenting claims that need to be backed by Credential Schemas and Definitions


```python
# these procedures allow the prover to retrieve from the ledger the relevant schemas and definitions
async def get_schema(pool_handle, _did, schema_id):
    get_schema_request = await ledger.build_get_schema_request(_did, schema_id)
    get_schema_response = await ledger.submit_request(pool_handle, get_schema_request)
    return await ledger.parse_get_schema_response(get_schema_response)


async def get_cred_def(pool_handle, _did, cred_def_id):
    get_cred_def_request = await ledger.build_get_cred_def_request(_did, cred_def_id)
    get_cred_def_response = await ledger.submit_request(pool_handle, get_cred_def_request)
    return await ledger.parse_get_cred_def_response(get_cred_def_response)

async def prover_get_schemas_and_definitions_from_ledger(pool_handle, _did, identifiers):
    """
    This takes the identifiers (response to a Credential Request) and returns Credentials Schemas and Definitions
    """
    schemas = {}
    cred_defs = {}
    for item in identifiers.values():
        (received_schema_id, received_schema) = await get_schema(pool_handle, _did, item['schema_id'])
        schemas[received_schema_id] = json.loads(received_schema)

        (received_cred_def_id, received_cred_def) = await get_cred_def(pool_handle, _did, item['cred_def_id'])
        cred_defs[received_cred_def_id] = json.loads(received_cred_def)

    return json.dumps(schemas), json.dumps(cred_defs)
```


```python
alice['schemas'], alice['cred_defs'] = \
        await prover_get_schemas_and_definitions_from_ledger(alice['pool'], alice['did_for_acme'],
                                              alice['creds_for_job_application_proof'])
```

Alice has everything now to **compute the proof**

She writes down all the credentials that need to be sent


```python
alice['job_application_requested_creds'] = json.dumps({
    'self_attested_attributes': {
        'attr1_referent': 'Alice',
        'attr2_referent': 'Garcia',
        'attr6_referent': '123-45-6789'
    },
    'requested_attributes': {
        'attr3_referent': {'cred_id': cred_for_attr3['referent'], 'revealed': True},
        'attr4_referent': {'cred_id': cred_for_attr4['referent'], 'revealed': True},
        'attr5_referent': {'cred_id': cred_for_attr5['referent'], 'revealed': True},
    },
    'requested_predicates': {'predicate1_referent': {'cred_id': cred_for_predicate1['referent']}}
})

```


```python

alice['job_application_proof'] = \
    await anoncreds.prover_create_proof(alice['wallet'], alice['job_application_proof_request'],
                                        alice['job_application_requested_creds'], alice['master_secret_id'],
                                        alice['schemas'], alice['cred_defs'], '{}') # empty dict because no revocation states

```

Alice has now a proof for the Job-Application Request

She will send it to Acme in a secure way


```python
acme['authcrypted_job_application_proof_request'] = \
    await crypto.auth_crypt(acme['wallet'], acme['key_for_alice'], acme['alice_key_for_acme'],
                            acme['job_application_proof_request'].encode('utf-8'))
```


```python
# recall to encrypt we need to pass to auth_crypt:
# wallet_handle: int,
# sender_vk: str,
# recipient_vk: str,
#  msg: bytes(encoded)

# here with 'acme_key_for_alice' we mean: the key acme produced to interact with alice (it is the recipient key)
alice['authcrypted_job_application_proof'] = await crypto.auth_crypt(alice['wallet'],alice['key_for_acme'],\
                                                                    alice['acme_key_for_alice'],\
                                                                    alice['job_application_proof'].encode("utf-8"))
```


```python
# send this encrypted proof to Acme
acme['authcrypted_job_application_proof'] = alice['authcrypted_job_application_proof']
```


```python
# Acme then decryptes the msg
# recall that the auth_decrypt returns a tuple (key, bytes(msg))
_, acme['job_application_proof_encoded'] = await crypto.auth_decrypt(acme['wallet'],acme['key_for_alice'],\
                                                                    acme['authcrypted_job_application_proof'])
```


```python
acme['job_application_proof'] = acme['job_application_proof_encoded'].decode("utf-8")
```


```python
# check that the proof Alice computed is the one that Acme got
```


```python
assert alice['job_application_proof'] == acme['job_application_proof']
```

The prover has now done and everything has been sent to the verifier

Since the verifier has got a proof over some claims, also she needs to retrieve from the ledger the relevant schemas and definitions


```python
async def verifier_get_schemas_and_definitions_from_ledger(pool_handle, _did, identifiers):
    schemas = {}
    cred_defs = {}
    for item in identifiers:
        (received_schema_id, received_schema) = await get_schema(pool_handle, _did, item['schema_id'])
        schemas[received_schema_id] = json.loads(received_schema)

        (received_cred_def_id, received_cred_def) = await get_cred_def(pool_handle, _did, item['cred_def_id'])
        cred_defs[received_cred_def_id] = json.loads(received_cred_def)

    return json.dumps(schemas), json.dumps(cred_defs)

```


```python
acme['schemas'], acme['cred_defs'] = \
        await verifier_get_schemas_and_definitions_from_ledger(acme['pool'], acme['did'],
                                                json.loads(acme['job_application_proof'])['identifiers'])

```


```python
decrypted_job_application_proof = json.loads(acme['job_application_proof'])
```


```python
# Assert that all the fields are consistent
assert 'Bachelor of Science, Marketing' == \
           decrypted_job_application_proof['requested_proof']['revealed_attrs']['attr3_referent']['raw']
assert 'graduated' == \
       decrypted_job_application_proof['requested_proof']['revealed_attrs']['attr4_referent']['raw']
assert '123-45-6789' == \
       decrypted_job_application_proof['requested_proof']['revealed_attrs']['attr5_referent']['raw']

assert 'Alice' == decrypted_job_application_proof['requested_proof']['self_attested_attrs']['attr1_referent']
assert 'Garcia' == decrypted_job_application_proof['requested_proof']['self_attested_attrs']['attr2_referent']
assert '123-45-6789' == decrypted_job_application_proof['requested_proof']['self_attested_attrs']['attr6_referent']

```


```python
acme['job_application_proof_request']
```




    '{"requested_attributes": {"attr3_referent": {"name": "degree", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}]}, "attr2_referent": {"name": "last_name"}, "attr1_referent": {"name": "first_name"}, "attr4_referent": {"name": "status", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}]}, "attr5_referent": {"name": "ssn", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}]}, "attr6_referent": {"name": "phone_number"}}, "name": "Job-Application", "nonce": "1432422343242122312411212", "version": "0.1", "requested_predicates": {"predicate1_referent": {"p_type": ">=", "name": "average", "restrictions": [{"cred_def_id": "Gqm3qg342RFovaL5U1rT1W:3:CL:16:TAG1"}], "p_value": 4}}}'



The overall proof of the request made by Acme is then verified


```python
assert await anoncreds.verifier_verify_proof(acme['job_application_proof_request'], acme['job_application_proof'],
                                                 acme['schemas'], acme['cred_defs'], '{}','{}')
                                            # empty dicts for the last arguments because no revocation is present
```

### Alice gets the Job


Acme sends a credential offer to Alice.

Alice answers with a credential request to Acme.


```python
 acme['job_certificate_cred_offer'] = await anoncreds.issuer_create_credential_offer(acme['wallet'], acme['job_certificate_cred_def_id'])
```


```python
### ASSUME SECRET EXCHANGE ###
alice['job_certificate_cred_offer'] = acme['job_certificate_cred_offer']
```

Alice has to answer back with a credential request.

In order to create the credential request Alice has to retrieve the credential definition.


```python
job_cred_def_id = json.loads(alice['job_certificate_cred_offer'])['cred_def_id']
```


```python
# we find the usual pattern: build request -> submit request -> parse response
get_cred_def_request = await ledger.build_get_cred_def_request(alice['did_for_acme'],job_cred_def_id )
get_cred_def_response = await ledger.submit_request(alice['pool'], get_cred_def_request)

alice['job_certificate_cred_def_id'], alice['job_certificate_cred_def'] = \
    await ledger.parse_get_cred_def_response(get_cred_def_response)
```


```python
# a check
job_cred_def_id == alice['job_certificate_cred_def_id']
```




    True



Alice creates a credential request


```python
alice['job_certificate_cred_req'], alice['job_certificate_cred_req_metadata'] = \
    await anoncreds.prover_create_credential_req(alice['wallet'], alice['did_for_acme'], alice['job_certificate_cred_offer'],
                                                 alice['job_certificate_cred_def'], alice['master_secret_id'])
```

Alice sends the credential request to ACME (assume secure connection)


```python
acme['job_certificate_cred_req'] = alice['job_certificate_cred_req']
```

Acme prepares all the documentation to issue the credential


```python
acme['job_certificate_cred_values'] = json.dumps({
    "first_name": {"raw": "Alice", "encoded": "245712572474217942457235975012103335"},
    "last_name": {"raw": "Garcia", "encoded": "312643218496194691632153761283356127"},
    "employee_status": {"raw": "Permanent", "encoded": "2143135425425143112321314321"},
    "salary": {"raw": "2400", "encoded": "2400"},
    "experience": {"raw": "10", "encoded": "10"}
})
```

Before issuing the credential, the issuer (Acme in this case) needs to open a storage reader on th revocation registry. This is to be given as argument to the procedure that will issue the credential


```python
# Acme opens the storage reader
acme['blob_storage_reader'] = await blob_storage.open_reader('default', acme['tails_writer_config'])
```


```python
acme['job_certificate_cred'], acme['job_certificate_cred_rev_id'], acme['alice_cert_rev_reg_delta'] = \
    await anoncreds.issuer_create_credential(acme['wallet'], acme['job_certificate_cred_offer'],
                                             acme['job_certificate_cred_req'],
                                             acme['job_certificate_cred_values'],
                                             acme['revoc_reg_id'],
                                             acme['blob_storage_reader'])
```


```python
# this is the local id of for revocation info of the credential
acme['job_certificate_cred_rev_id']
```




    '1'



Acme publishes a revocation registry into the ledger so that other parties can query it


```python
acme['revoc_reg_entry_req'] = \
        await ledger.build_revoc_reg_entry_request(acme['did'], acme['revoc_reg_id'], 'CL_ACCUM',
                                                   acme['alice_cert_rev_reg_delta'])

await ledger.sign_and_submit_request(acme['pool'], acme['wallet'], acme['did'], acme['revoc_reg_entry_req'])

```




    '{"result":{"txnMetadata":{"txnId":"5:8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag","txnTime":1572973265,"seqNo":28},"ver":"1","txn":{"protocolVersion":2,"metadata":{"payloadDigest":"cf02c118303b5724b7bf88960c2a0d5f23543bd1c7169c9e9e0c72b04199f003","reqId":1572973265184835803,"from":"8hFKa2Xos6A7EPT2SC3edb","digest":"16ceed106e99d49845a951533375bad361f77a2bae056581fec47a1485e5d601"},"type":"114","data":{"value":{"issued":[1],"prevAccum":"1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000 2 095E45DDF417D05FB10933FFC63D474548B7FFFF7888802F07FFFFFF7D07A8A8 1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000","accum":"21 10636E4CE539505B36801D02EA2486E552BFCEBAE3390CE865FA5D81A89C6EDDB 21 128761AA5DEB105548CE6976546BC5CC00BC87949BD62721305B9BD4054243084 6 8A045E537942402425462ABBAF236F9DD3809D93C09544DD4FC64DB1DD92B9C6 4 2E0832E0A0EE5DC5A2284C1B3CA0BBC1C37E392F4F15547E167FEDD1E0A9374C 6 8E7D0E6FFA798940B1871F365AFE73D7985C20522E8C84276B94F1A51621E922 4 30F5103082EB2ADA50E45DD0D4759B887DC759BDDFE3308580EBDF9E2D05C7D8"},"revocDefType":"CL_ACCUM","revocRegDefId":"8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag"}},"rootHash":"6AiyCmMkmAWr9tFSekE2xRbPxsz1abHQWAFT6zcmW9PK","reqSignature":{"type":"ED25519","values":[{"value":"3y8bVZrGUUgvANQuJakxn5JHh1sNHv5Bsb9EpcTfzvyiX3W24pft2aetoP6V3mudKDzWUCHZcLdKCCDUn9ZfA3oD","from":"8hFKa2Xos6A7EPT2SC3edb"}]},"auditPath":["CutSBkBAmgFFcMpiWAbFC1JUV51gFqGJdJ5UHV5zuQFS","BuG1xuh2Yk8btGU8ckJYKbDRzc9KzooCumWrgo2uJhmj","GUy2CLxQHfmiCGiaTs2ncNQ5QvQp7ZqyShZQjRjoN2DY","H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs"]},"op":"REPLY"}'




```python
# Alice gets the job certificate credential
alice['job_certificate_cred'] = acme['job_certificate_cred']
```

Before adding the certificate to her wallet, Alice has to query the revocation registry concerning that credential

To store the credential, she needs the revocation registry definition that she can got from the ledger as follows


```python
# build the request
alice['acme_revoc_reg_des_req'] = \
        await ledger.build_get_revoc_reg_def_request(alice['did_for_acme'],
                                                     json.loads(alice['job_certificate_cred'])['rev_reg_id'])

```


```python
# send the request
alice['acme_revoc_reg_des_resp'] = await ledger.submit_request(alice['pool'], alice['acme_revoc_reg_des_req'])

(alice['acme_revoc_reg_def_id'], alice['acme_revoc_reg_def_json']) = \
    await ledger.parse_get_revoc_reg_def_response(alice['acme_revoc_reg_des_resp'])
```

Now Alice can store the credential in her wallet and get the referent


```python
 await anoncreds.prover_store_credential(alice['wallet'], None, alice['job_certificate_cred_req_metadata'],
                                          alice['job_certificate_cred'], alice['job_certificate_cred_def'], alice['acme_revoc_reg_def_json'])
```




    '001b2d30-bc41-4641-9ec2-755932fb0078'



<a id='alice_loan'></a>
# Alice asks for a loan

First of all we create a new agent: the Thrift bank


```python
thrift = {
  'name': "Thrift Bank",
  'wallet_config': json.dumps({'id': 'thrift_wallet'}),
  'wallet_credentials': json.dumps({'key': 'thrift_wallet_key'}),
  'pool': pool_handle,
  'seed': '000000000000000000000000Thrift01'
}
await wallet.create_wallet(thrift['wallet_config'], thrift['wallet_credentials'])
thrift['wallet'] = await wallet.open_wallet(thrift['wallet_config'], thrift['wallet_credentials'])

```


```python
thrift['did'], thrift['key'] = await did.create_and_store_my_did(thrift['wallet'],json.dumps({'seed':thrift['seed']}))
```

Just assume all the onboarding done correctly. We assign the previous did the role of TA


```python
nym_request = await ledger.build_nym_request(steward['did'],thrift['did'],thrift['key'],None,'TRUST_ANCHOR')
res = await ledger.sign_and_submit_request(steward['pool'],steward['wallet'],steward['did'],nym_request)
```

Before issuing a loan Thrift launches a challenge to Alice.

Just recall that anytime we have thrift[a_thing] = alice[a_thing] we are assuming that the exchange of data took place encrypted.

Thrift creates a proof request to be sent to Alice


```python
thrift['apply_loan_proof_request'] = json.dumps({
  'nonce': '123432421212',
  'name': 'Loan-Application-Basic',
  'version': '0.1',
  'requested_attributes': {
      'attr1_referent': {
          'name': 'employee_status',
          'restrictions': [{'cred_def_id': acme['job_certificate_cred_def_id']}]
      }
  },
  'requested_predicates': {
      'predicate1_referent': {
          'name': 'salary',
          'p_type': '>=',
          'p_value': 2000,
          'restrictions': [{'cred_def_id': acme['job_certificate_cred_def_id']}]
      },
      'predicate2_referent': {
          'name': 'experience',
          'p_type': '>=',
          'p_value': 1,
          'restrictions': [{'cred_def_id': acme['job_certificate_cred_def_id']}]
      }
  },
  'non_revoked': {'to': int(time.time())}
})
```


```python
# Alice gets the request
alice['apply_loan_proof_request'] = thrift['apply_loan_proof_request']
```


```python
# Alice search for the credential to be used to answer back the request
search_for_apply_loan_proof_request = \
        await anoncreds.prover_search_credentials_for_proof_req(alice['wallet'],
                                                                alice['apply_loan_proof_request'], None)

```


```python
# we use the procedure written in the previously when retrieving data using the search handle

cred_for_attr1 = await get_credential_for_referent(search_for_apply_loan_proof_request, 'attr1_referent')
cred_for_predicate1 = await get_credential_for_referent(search_for_apply_loan_proof_request, 'predicate1_referent')
cred_for_predicate2 = await get_credential_for_referent(search_for_apply_loan_proof_request, 'predicate2_referent')

```


```python
# close the search handle
await anoncreds.prover_close_credentials_search_for_proof_req(search_for_apply_loan_proof_request)
```


```python
# as we can see Alice has only one credential that meets all the proof requirements
cred_for_attr1
```




    {'attrs': {'employee_status': 'Permanent',
      'experience': '10',
      'first_name': 'Alice',
      'last_name': 'Garcia',
      'salary': '2400'},
     'cred_def_id': '8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1',
     'cred_rev_id': '1',
     'referent': '001b2d30-bc41-4641-9ec2-755932fb0078',
     'rev_reg_id': '8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag',
     'schema_id': 'ABS4UwqvF84EG9h3B6HeL2:2:Job-Certificate:0.2'}



Since the credential being used here to answer the proof is revokable Alice needs to query the revocation registry.

We say that Alice creates a revocation state.

The idea is that in a proof the prover is responsible for more work than the verifier.


```python
# in order to query it Alice needs to open a storage reader
alice['tails_reader_config'] = json.dumps({'base_dir': str(Path.home().joinpath('.indy_client').joinpath("tails")), 'uri_pattern': ''})
alice['blob_storage_reader'] = await blob_storage.open_reader('default', alice['tails_reader_config'])
```

Alice needs to **create** the revocation state at that particular moment for that specific credential.

#### Alice gets the delta of the revocation registry from the ledger

It is duty of the prover to create the revocation states at a particular moment in time.

The verifier will get these states from the ledger.

In order to create the state at that particular moment, Alice needs to retrieve the revocation delta, the revocation definitions and the credential id of the revocation. This is done by querying the ledger with a request submit action.

Then Alice creates the necessary revocation states with all the information she retrieves.

We have wrote the procedure *prover_create_revocation_states* that from the credentials used for the proof the revocation states are computed and disposed in the right data structure. The code for this is stored in the module imported into this notebook.

As far as concerning the time of non revocation, it is the verifier that asks for a particular time in which the credential does not have to be revoked.

We wrote a procedure that extracts such information from the proof request sent to the prover by the verifier.


```python
_from, to = extract_revocation_time_from_proof_request(alice['apply_loan_proof_request'])
```


```python
_from, to
```




    (0, 1572973267)



Now Alice has the revocation state that she can use to compute the proof to be sent to Thrift


```python
alice['apply_loan_requested_creds'] = json.dumps({
        'self_attested_attributes': {},
        'requested_attributes': {
            'attr1_referent': {'cred_id': cred_for_attr1['referent'], 'revealed': True, 'timestamp': to}
        },
        'requested_predicates': {
            'predicate1_referent': {'cred_id': cred_for_predicate1['referent'], 'timestamp': to},
            'predicate2_referent': {'cred_id': cred_for_predicate2['referent'], 'timestamp': to}
        }
    })
```

Alice gets the schemas and the credential definitions (we use the procedures used when getting the transcript)


```python
alice['creds_for_loan_application_proof'] = {cred_for_attr1['referent']: cred_for_attr1,
                                             cred_for_predicate1['referent']: cred_for_predicate1,
                                             cred_for_predicate2['referent']: cred_for_predicate2}
```


```python
alice['creds_for_loan_application_proof']
```




    {'001b2d30-bc41-4641-9ec2-755932fb0078': {'attrs': {'employee_status': 'Permanent',
       'experience': '10',
       'first_name': 'Alice',
       'last_name': 'Garcia',
       'salary': '2400'},
      'cred_def_id': '8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1',
      'cred_rev_id': '1',
      'referent': '001b2d30-bc41-4641-9ec2-755932fb0078',
      'rev_reg_id': '8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag',
      'schema_id': 'ABS4UwqvF84EG9h3B6HeL2:2:Job-Certificate:0.2'}}




```python
# all schemas json participating in the proof request in dict with pair (key=schema_id, value=schema_json)
# all cred defs json participating in the proof request in dict with pair (key=cred_def_id, value=cred_def_json)
alice['loan_schemas'], alice['loan_cred_defs'] = \
        await prover_get_schemas_and_definitions_from_ledger(alice['pool'], alice['did_for_acme'],
                                              alice['creds_for_loan_application_proof'])
```


```python

alice['revoc_states_for_loan_app'] = await prover_create_revocation_states(alice['pool'], alice['blob_storage_reader'], alice['did_for_acme'],
                                            alice['creds_for_loan_application_proof'],
                                            _from=_from, _to= to)
```


```python

```


```python
alice['revoc_states_for_loan_app']
```




    '{"8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag": {"1572973267": {"witness": {"omega": "1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000 2 095E45DDF417D05FB10933FFC63D474548B7FFFF7888802F07FFFFFF7D07A8A8 1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000 1 0000000000000000000000000000000000000000000000000000000000000000"}, "rev_reg": {"accum": "21 10636E4CE539505B36801D02EA2486E552BFCEBAE3390CE865FA5D81A89C6EDDB 21 128761AA5DEB105548CE6976546BC5CC00BC87949BD62721305B9BD4054243084 6 8A045E537942402425462ABBAF236F9DD3809D93C09544DD4FC64DB1DD92B9C6 4 2E0832E0A0EE5DC5A2284C1B3CA0BBC1C37E392F4F15547E167FEDD1E0A9374C 6 8E7D0E6FFA798940B1871F365AFE73D7985C20522E8C84276B94F1A51621E922 4 30F5103082EB2ADA50E45DD0D4759B887DC759BDDFE3308580EBDF9E2D05C7D8"}, "timestamp": 1572973267}}}'



Alice computes the proof to send to Thrift


```python
alice['apply_loan_proof'] = \
            await anoncreds.prover_create_proof(alice['wallet'], alice['apply_loan_proof_request'],
                                                alice['apply_loan_requested_creds'], alice['master_secret_id'],
                                                alice['loan_schemas'], alice['loan_cred_defs'],
                                                alice['revoc_states_for_loan_app'])
```


```python
# send the proof to Thrift
thrift['alice_apply_loan_proof'] = alice['apply_loan_proof']
```


```python
json.loads(thrift['alice_apply_loan_proof'])['identifiers']
```




    [{'cred_def_id': '8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1',
      'rev_reg_id': '8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag',
      'schema_id': 'ABS4UwqvF84EG9h3B6HeL2:2:Job-Certificate:0.2',
      'timestamp': 1572973267}]



#### Thrift has to verify the proof

In the role of verifier, Thrift needs to retrieve from the ledger the schemas, definitions and registries.

Indeed we recall that all required schemas, public keys and revocation registries must be provided to **verify** the proof.


```python
thrift['schemas_for_loan_app'],thrift['cred_defs_for_loan_app']=\
        await verifier_get_schemas_and_definitions_from_ledger(thrift['pool'],thrift['did'],
                                                json.loads(thrift['alice_apply_loan_proof'])['identifiers'])
```

The following is to retrieve the revocation info.

We do it manually since it is just an identifier. We should come up with a procedure to automate it.


```python
json.loads(thrift['alice_apply_loan_proof'])['identifiers']
```




    [{'cred_def_id': '8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1',
      'rev_reg_id': '8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag',
      'schema_id': 'ABS4UwqvF84EG9h3B6HeL2:2:Job-Certificate:0.2',
      'timestamp': 1572973267}]




```python
identifier = json.loads(thrift['alice_apply_loan_proof'])['identifiers'][0]
```


```python
identifiers = json.loads(thrift['alice_apply_loan_proof'])['identifiers']
```


```python
identifiers
```




    [{'cred_def_id': '8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1',
      'rev_reg_id': '8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag',
      'schema_id': 'ABS4UwqvF84EG9h3B6HeL2:2:Job-Certificate:0.2',
      'timestamp': 1572973267}]




```python
revoc_reg_defs_json, revoc_regs_json = await verifier_get_revocation_info_for_proof_verification(thrift['pool'], thrift['did'], identifiers)
```


```python
thrift['revoc_defs_for_loan_app'] = revoc_reg_defs_json
thrift['revoc_regs_for_loan_app'] = revoc_regs_json
```


```python
assert await anoncreds.verifier_verify_proof(thrift['apply_loan_proof_request'],
                                             thrift['alice_apply_loan_proof'],
                                             thrift['schemas_for_loan_app'],
                                             thrift['cred_defs_for_loan_app'],
                                             thrift['revoc_defs_for_loan_app'],
                                             thrift['revoc_regs_for_loan_app'])
```


```python
revoc_reg_defs_json
```




    '{"8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag": {"credDefId": "8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1", "tag": "cred_def_tag", "id": "8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag", "value": {"issuanceType": "ISSUANCE_ON_DEMAND", "tailsHash": "7iDLRaoXFPH4tpWv67Vp872vwFkKaMfvTP7PaZnyFSdn", "maxCredNum": 5, "publicKeys": {"accumKey": {"z": "1 1D81FBB4FBEB35AB3007875255606F4A922EDD0385306A689032B84D51F53446 1 14C45A8A7568C3D826645512E5AFA912445EB3AEDCA28179869522591A904611 1 16E154DF6EDF5991064B103122B5D25602F21D2DFC9B6F5C71EA315613CD1B1B 1 10B9167E5868358AA501ED62F9E7CE61EE79E62142731B40AE1B3E81B4EB07AF 1 01B4A7EDE7616E6FFE1D5FB295A5DAFC11966AF1408B296D108581E721EC28FE 1 1FDBAA6CDBFBCB6BCC456900675745FEE69B79D6A8BBFD20E1E56FC363BAFE22 1 001408FF2D7DDA1E4BFE26585496E7ED54CD5F14C9D8F7A9514D4EAD9727D9A0 1 15E7741FF555C41C4BFBE05145FDB4622B873594CF983FD6762318B0B39D0B60 1 0A79533EA65B160021E89C7B12CE959836BFA2C51B8938B68485CA1B062DF64A 1 150D71178EFF3A75D186D634600C644454E0B337EF211CE378F111F1915E56D5 1 21F4B8390558A197CF5B3082F6485879B1C98A157F3DD20C24B295915334AE42 1 0F0C512764D1BC4D100ECDAF6A94A030BAFE0CB267A17922A8731BFA3826C498"}}, "tailsLocation": "/root/.indy_client/tails/7iDLRaoXFPH4tpWv67Vp872vwFkKaMfvTP7PaZnyFSdn"}, "revocDefType": "CL_ACCUM", "ver": "1.0"}}'



**NB**: There are 3 requests that can be built concerning the revocation: the definition, the delta, the state
Each one of them requires a specific procedure to be parced. For instance the third one requires *parse_get_revoc_reg_response*

<a id="alice_quits_job"></a>
# Alice quits her job

The issuer of the credential will be the one entitled to revoke, if she is allowed to.

After the revocation, the information needs to be sent to the ledger.


```python
# issuer_revoke_credential will return a delta revocation registry that as such will be sent to the ledger
rev_reg_delta = await anoncreds.issuer_revoke_credential(acme['wallet'],
                                         acme['blob_storage_reader'],
                                         acme['revoc_reg_id'],
                                         acme['job_certificate_cred_rev_id'])

```


```python
rev_reg_delta_request = \
        await ledger.build_revoc_reg_entry_request(acme['did'], acme['revoc_reg_id'], 'CL_ACCUM',
                                                   rev_reg_delta)

await ledger.sign_and_submit_request(acme['pool'], acme['wallet'], acme['did'],rev_reg_delta_request)
```




    '{"result":{"txnMetadata":{"txnId":"5:8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag","txnTime":1572973268,"seqNo":30},"ver":"1","txn":{"protocolVersion":2,"metadata":{"payloadDigest":"526a07744f937ea17de904796fb93ec2fa17b1f66cc4df0a2138cfa9f5b4edb3","reqId":1572973268573031035,"from":"8hFKa2Xos6A7EPT2SC3edb","digest":"b64dcc9ec235f7f6809a70d4ef6d537c7fae11e162ce60e2e653785ec6bdaa0d"},"type":"114","data":{"value":{"prevAccum":"21 10636E4CE539505B36801D02EA2486E552BFCEBAE3390CE865FA5D81A89C6EDDB 21 128761AA5DEB105548CE6976546BC5CC00BC87949BD62721305B9BD4054243084 6 8A045E537942402425462ABBAF236F9DD3809D93C09544DD4FC64DB1DD92B9C6 4 2E0832E0A0EE5DC5A2284C1B3CA0BBC1C37E392F4F15547E167FEDD1E0A9374C 6 8E7D0E6FFA798940B1871F365AFE73D7985C20522E8C84276B94F1A51621E922 4 30F5103082EB2ADA50E45DD0D4759B887DC759BDDFE3308580EBDF9E2D05C7D8","revoked":[1],"accum":"21 1291B24120000000DD1A26C0000000043090800000000009D3800000000000098 21 1291B24120000000DD1A26C0000000043090800000000009D3800000000000098 6 6F3A452B089C1824ECD0F5542FFF86A30BC7B0E53ABC14BB9CB1FADDC55E4F3E 4 278D432A3316284F92BD9E09C3052EA621974D621A244AC46AF8BCF27DB81052 6 948D920900000006E8D1360000000021848400000000004E9C0000000000004C 4 4A46C9048000000374689B0000000010C2420000000000274E00000000000026"},"revocDefType":"CL_ACCUM","revocRegDefId":"8hFKa2Xos6A7EPT2SC3edb:4:8hFKa2Xos6A7EPT2SC3edb:3:CL:17:TAG1:CL_ACCUM:cred_def_tag"}},"rootHash":"AfqobFaksz9pZJReuw71kB3fDT6oAVeFucETq2tnJRQT","reqSignature":{"type":"ED25519","values":[{"value":"3MvTygEDcAjacWmfR2JcgL2GFnYhzYA9sZwLeAchiqccTawKR7Y2smkTuuD9MGNww67gTNcdV4hD3UReabNhmt73","from":"8hFKa2Xos6A7EPT2SC3edb"}]},"auditPath":["HPdH3zkuoNDdY99BzZ4bpPbdZgvC2JFxLN92EAzRZAh5","HjorgtvrghbpwhdXQTzBftJ9FHTJPjHr5r566xDNUNV6","GUy2CLxQHfmiCGiaTs2ncNQ5QvQp7ZqyShZQjRjoN2DY","H8E64v6eM6whdHeTe2J8gTKjv9P1ruoSGLEdAWhdXkrs"]},"op":"REPLY"}'



If the above code ran again, the assertion would fail!

The following is to show that such a proof will not be successfully verified.

Indeed suppose that Thrift asks again to prove the credential


```python
thrift['apply_loan_proof_request'] = json.dumps({
  'nonce': '123432421212',
  'name': 'Loan-Application-Basic',
  'version': '0.1',
  'requested_attributes': {
      'attr1_referent': {
          'name': 'employee_status',
          'restrictions': [{'cred_def_id': acme['job_certificate_cred_def_id']}]
      }
  },
  'requested_predicates': {
      'predicate1_referent': {
          'name': 'salary',
          'p_type': '>=',
          'p_value': 2000,
          'restrictions': [{'cred_def_id': acme['job_certificate_cred_def_id']}]
      },
      'predicate2_referent': {
          'name': 'experience',
          'p_type': '>=',
          'p_value': 1,
          'restrictions': [{'cred_def_id': acme['job_certificate_cred_def_id']}]
      }
  },
  'non_revoked': {'to': int(time.time())}
})
```


```python
# Alice gets the request
alice['apply_loan_proof_request'] = thrift['apply_loan_proof_request']
```

Alice retrieves all the necessary elements to construct the proof


```python
# Alice search for the credential to be used to answer back the request
search_for_apply_loan_proof_request = \
        await anoncreds.prover_search_credentials_for_proof_req(alice['wallet'],
                                                                alice['apply_loan_proof_request'], None)
# we use the procedure written in the previously when retrieving data using the search handle

cred_for_attr1 = await get_credential_for_referent(search_for_apply_loan_proof_request, 'attr1_referent')
cred_for_predicate1 = await get_credential_for_referent(search_for_apply_loan_proof_request, 'predicate1_referent')
cred_for_predicate2 = await get_credential_for_referent(search_for_apply_loan_proof_request, 'predicate2_referent')

await anoncreds.prover_close_credentials_search_for_proof_req(search_for_apply_loan_proof_request)

_from, to = extract_revocation_time_from_proof_request(alice['apply_loan_proof_request'])

alice['apply_loan_requested_creds'] = json.dumps({
        'self_attested_attributes': {},
        'requested_attributes': {
            'attr1_referent': {'cred_id': cred_for_attr1['referent'], 'revealed': True, 'timestamp': to}
        },
        'requested_predicates': {
            'predicate1_referent': {'cred_id': cred_for_predicate1['referent'], 'timestamp': to},
            'predicate2_referent': {'cred_id': cred_for_predicate2['referent'], 'timestamp': to}
        }
    })

alice['creds_for_loan_application_proof'] = {cred_for_attr1['referent']: cred_for_attr1,
                                             cred_for_predicate1['referent']: cred_for_predicate1,
                                             cred_for_predicate2['referent']: cred_for_predicate2}

alice['loan_schemas'], alice['loan_cred_defs'] = \
        await prover_get_schemas_and_definitions_from_ledger(alice['pool'], alice['did_for_acme'],
                                              alice['creds_for_loan_application_proof'])


alice['revoc_states_for_loan_app'] = await prover_create_revocation_states(alice['pool'], alice['blob_storage_reader'], alice['did_for_acme'],
                                            alice['creds_for_loan_application_proof'],
                                            _from=_from, _to= to)


```

Alice computes the proof to be sent to Thrift


```python
alice['apply_loan_proof'] = \
            await anoncreds.prover_create_proof(alice['wallet'], alice['apply_loan_proof_request'],
                                                alice['apply_loan_requested_creds'], alice['master_secret_id'],
                                                alice['loan_schemas'], alice['loan_cred_defs'],
                                                alice['revoc_states_for_loan_app'])
```

She sends the new proof to Thrift


```python
# send the proof to Thrift
thrift['alice_apply_loan_proof'] = alice['apply_loan_proof']
```

Thrift gets all the necessary elements to verify the proof


```python
thrift['schemas_for_loan_app'],thrift['cred_defs_for_loan_app']=\
        await verifier_get_schemas_and_definitions_from_ledger(thrift['pool'],thrift['did'],
                                                json.loads(thrift['alice_apply_loan_proof'])['identifiers'])
identifiers = json.loads(thrift['alice_apply_loan_proof'])['identifiers']

revoc_reg_defs_json, revoc_regs_json = await verifier_get_revocation_info_for_proof_verification(thrift['pool'], thrift['did'], identifiers)

thrift['revoc_defs_for_loan_app'] = revoc_reg_defs_json
thrift['revoc_regs_for_loan_app'] = revoc_regs_json
```

And verifies the claim


```python
assert await anoncreds.verifier_verify_proof(thrift['apply_loan_proof_request'],
                                             thrift['alice_apply_loan_proof'],
                                             thrift['schemas_for_loan_app'],
                                             thrift['cred_defs_for_loan_app'],
                                             thrift['revoc_defs_for_loan_app'],
                                             thrift['revoc_regs_for_loan_app'])
```


    ---------------------------------------------------------------------------

    AssertionError                            Traceback (most recent call last)

    <ipython-input-181-31d49fd9faec> in async-def-wrapper()


    AssertionError:


That, as expected, fails since at this time the credentials being used to construct the proof had been revoked

Now we have attached a revocation registry to the credential issued by Acme.
