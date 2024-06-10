# Clone a new catalog from an existing one

The script [clone_catalog.sh](clone_catalog.sh) will clone all products and APIs and their subscriptions including cOrgs/Apps along with their credentials in a given `source catalog space` to the specified `target catalog space`.

## Assumptions:

0. The target catalog and space are setup properly, including compatible gw and uer registries.
1. Compatible onboarding URs are configured on the target catalog
2. All OAuth providers are configured on the target catalog / space
3. All TLS client profiles are configured on the target catalog / space
4. All API URs are configured on the target catalog / space
5. Since user passwords in local UR cannot be ported, default password `7iron-hide` is created for all users.

Note: When space is enabled -
1. Only products are deployed / visible at the space level 
2. cOrgs/apps/subscriptions are still at the catalog level, i.e. they are visible to all spaces.
3. REST APIs / apic toolkit will not filter out cOrgs/apps/subscriptions at space level even they provide filtering options.
4. So we will ignore those apic space options for cOrgs/apps/subscriptions options.


## How to use the script

* Download this script package:
  * The main script [clone_catalog.sh](clone_catalog.sh)
  * THe [property files](env/)
    * [apic.properties](env/apic.properties): specify source and target envs
    * catalog property setting files
* Customize the [apic.properties](env/apic.properties) for your own source and target envs
* Run [clone_catalog.sh](clone_catalog.sh)
```
 ./clone_catalog.sh 2>&1 | tee clone_catalog.log
```
* Check the log for any errors or warnings.
* Check the target catalog / space 
* Run API tests


Sample `apic.properties`:
```
#=============================
# source catalog properties
#=============================
src_host=mgmt.v10.apicww.cloud
src_user=kai
src_pwd=****
src_realm=provider/playground-ldap

src_org=middleearth
src_catalog=test-cat
src_space=test-space1

src_lur=test-cat-catalog

# temp directory to save src prods and apis
src_prods_dir=prods

#=============================
# target catalog properties
#=============================
target_host=mgmt.v10.apicww.cloud
target_user=kai
target_pwd=****
target_realm=provider/playground-ldap

target_org=middleearth
target_catalog=test2-cat
target_space=test2-cat

target_lur=test2-cat-catalog-0

```

## Steps in the script

1. clone catalog products and APIs
2. recreate them in the new catalog

### Migrate Products and APIs

Login API mgr
```
$ apic login -s mgmt.v10.apicww.cloud -u kai -p ****** -r provider/playground-ldap
Logged into mgmt.v10.apicww.cloud successfully
```

Show all products and contained APIs in the source catalog
```
$ apic products:list-all --scope space -s mgmt.v10.apicww.cloud -o middleearth -c test-cat --space test-cat

echo-product:1.0.0        [state: published]   https://mgmt.v10.apicww.cloud/api/spaces/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/e7ec1b97-e5fe-4548-94be-69d53e924b01/products/9a825b50-1c74-400e-b6b9-a31b57a6229d
pokemon-product:1.0.0     [state: published]   https://mgmt.v10.apicww.cloud/api/spaces/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/e7ec1b97-e5fe-4548-94be-69d53e924b01/products/369506da-10ec-4be3-85c9-0566c596d0b8
loopback-product:1.0.0    [state: published]   https://mgmt.v10.apicww.cloud/api/spaces/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/e7ec1b97-e5fe-4548-94be-69d53e924b01/products/f879d076-6eed-453e-b398-dce6f9b060df
```

Get / clone all products and contained APIs in the source catalog
```
$ apic products:clone --scope space -s mgmt.v10.apicww.cloud -o middleearth -c test-cat --space test-cat

echo:1.0.0           echo_1.0.0.yaml
echo-product:1.0.0   echo-product_1.0.0.yaml
pokemon:1.0.0           pokemon_1.0.0.yaml
pokemon-product:1.0.0   pokemon-product_1.0.0.yaml
loopback:1.0.0           loopback_1.0.0.yaml
loopback-product:1.0.0   loopback-product_1.0.0.yaml
```

Publish all products to target catalog / space
```
$ apic products:publish echo-product_1.0.0.yaml --scope space -s mgmt.v10.apicww.cloud -o middleearth -c test-cat --space test-space1

echo-product:1.0.0    [state: published]   https://mgmt.v10.apicww.cloud/api/spaces/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/7e71442e-c016-44b7-bf73-a0e1a4646f54/products/5b956200-62f9-49c0-a3e6-d5c879463854
```

### Migrate consumer orgs

#### Create cOrg owners and members

Get all local users from source LUR
```
$ apic users:list -s mgmt.v10.apicww.cloud -o middleearth --user-registry cd6af9ce-83c4-4477-8d77-b093ba302493

mkz104    [state: enabled]   https://mgmt.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493/users/67a06b31-8bc2-400b-9d29-3e6eb50a21eb
mkz102    [state: enabled]   https://mgmt.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493/users/0918f186-bfb5-4c65-869c-d2189ff947b0
mkz101    [state: enabled]   https://mgmt.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493/users/3435cfcc-2d2d-407e-9d4a-fd66c63f53d3
mkz100    [state: enabled]   https://mgmt.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493/users/37c6b46e-3420-4fe5-8a49-b72be7a990b3
```

Retrieve Users from source LUR
```
apic users:get mkz100 -s mgmt.v10.apicww.cloud -o middleearth --user-registry cd6af9ce-83c4-4477-8d77-b093ba302493
mkz100   mkz100.yaml   https://mgmt.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493/users/37c6b46e-3420-4fe5-8a49-b72be7a990b3 
```

Add default password `7iron-hide` to all user yaml files -
* e.g. mkz104.yaml (a user definition for local UR) is adapted from the source user mkz100.yaml by adding the `password` field. 
```
type: user
api_version: 2.0.0
id: 37c6b46e-3420-4fe5-8a49-b72be7a990b3
name: mkz105
title: mkz105
state: enabled
identity_provider: test-cat-idp
username: mkz105
email: mkz105@gmail.com
first_name: Kai
last_name: Zhang
created_at: '2022-01-18T07:10:10.000Z'
updated_at: '2022-01-18T07:10:10.000Z'
org_url: 'https://cm.v10.apicww.cloud/api/orgs/c6312872-9f34-4f18-b626-b5dbddde87aaqq'
user_registry_url: >-
  https://cm.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493qq
url: >-
  https://cm.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493/users/37c6b46e-3420-4fe5-8a49-b72be7a990b3qq
password: 7iron-hide
```

Create all users in the target LUR
```
$ apic users:create mkz105-new.yaml -s mgmt.v10.apicww.cloud -o middleearth --user-registry cd6af9ce-83c4-4477-8d77-b093ba302493

mkz105    [state: enabled]   https://mgmt.v10.apicww.cloud/api/user-registries/c6312872-9f34-4f18-b626-b5dbddde87aa/cd6af9ce-83c4-4477-8d77-b093ba302493/users/6de9bd50-82f2-43d6-b4b7-33d5d71f9431  
```

#### Create cOrg

Get all source cOrgs
```
apic consumer-orgs:list -s mgmt.v10.apicww.cloud -o middleearth -c test-cat

corg102    [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/4e2527b6-fe9b-4e23-938f-8f1111fd7b09   
corg101    [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/3fe4aae9-b21d-415c-9e65-19adaa4cf448   
corg100    [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/753bd5ea-199e-42e7-9766-cd1bd7d51884   
corg4      [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/19536a4b-e255-449f-ac0d-5b36b426608e   
corg3      [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/89209daa-7fa2-4696-800e-1d3bfea52bf8   
corg2      [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/06f221f1-17ad-4b33-b545-54f69e2c064e   
corg1      [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/a2880aba-db37-4ea2-b6f1-baa2f813dfde   
```

```
apic consumer-orgs:get corg100 -s mgmt.v10.apicww.cloud -o middleearth -c test-cat
```

Replace `owner_url` with `target-server`, `target pOrg`, `UR name` and `owner name` - 
https://`target-server`/api/user-registries`/target-porg/target-ur`/users/`mkz100`
```
type: consumer_org
api_version: 2.0.0
id: 753bd5ea-199e-42e7-9766-cd1bd7d51884
name: corg102
title: corg102
state: enabled
owner_url: >-
  https://mgmt.v10.apicww.cloud/api/user-registries/middleearth/test-cat-catalog/users/mkz100
created_at: '2022-01-18T19:23:49.000Z'
updated_at: '2022-01-18T19:23:49.000Z'
org_url: 'https://cm.v10.apicww.cloud/api/orgs/c6312872-9f34-4f18-b626-b5dbddde87aaqq'
catalog_url: >-
  https://cm.v10.apicww.cloud/api/catalogs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4qq
url: >-
  https://cm.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/753bd5ea-199e-42e7-9766-cd1bd7d51884qq
```

Create cOrg on target catalog
```
apic consumer-orgs:create corg102-new.yaml -s mgmt.v10.apicww.cloud -o middleearth -c test-cat
corg102    [state: enabled]   https://mgmt.v10.apicww.cloud/api/consumer-orgs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/4e2527b6-fe9b-4e23-938f-8f1111fd7b09   
```

#### Create apps on target catalog / space

```
    # get all apps in the corg
    echo === apic apps:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg --space $src_space --space-initiated 
    apps=$(apic apps:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg --space $src_space --space-initiated | sed "s| .*||")
    apparray=($apps)
    for app in "${apparray[@]}"; do
        # get app from src
        echo === apic apps:get $app -s $src_host -o $src_org -c $src_catalog --consumer-org $corg --space $src_space --space-initiated
        apic apps:get $app -s $src_host -o $src_org -c $src_catalog --consumer-org $corg --space $src_space --space-initiated

        # remove the app_credential_urls and lines after it
        sed -i '/app_credential_urls/,$d' $app.yaml

        # create app on target (credentials are auto-created)
        echo === apic apps:create $app.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg --space $target_space --space-initiated
        apic apps:create $app.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg --space $target_space --space-initiated

        # get credentials of the app
        creds=$(apic credentials:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app | sed "s| .*||")
        credsarray=($creds)

        first=1
        for cred in "${credsarray[@]}"; do
            # get credentials from src app
            echo === apic credentials:get $cred -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app
            apic credentials:get $cred -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app 

            if [ $first -eq 1 ]; then
                # update the auot-gen credentials
                first=0
                echo === apic credentials:update credential-for-$app $cred.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg -a $app
                apic credentials:update credential-for-$app $cred.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg -a $app
            else
                # create / add extra credentials
                echo === apic credentials:create $cred.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg -a $app
                apic credentials:create $cred.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg -a $app
            fi
        done
    done
    cd ..
done
cd ..

# reset catalog setting hash_client_secret=false
echo === apic catalog-settings:update env/catalog-setting-hash-false.yaml -s $target_host -o $target_org -c $target_catalog
apic catalog-settings:update env/catalog-setting-hash-false.yaml -s $target_host -o $target_org -c $target_catalog
```

#### Create subscriptions

Get all subs from the source app
```
$ apic subscriptions:list -s mgmt.v10.apicww.cloud -o middleearth -c test-cat --consumer-org corg1 -a testapp1

loopback-product-1-0-0-default      [state: enabled]   https://mgmt.v10.apicww.cloud/api/apps/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/a2880aba-db37-4ea2-b6f1-baa2f813dfde/d029b425-3bcc-473b-a023-ca29adaa5f27/subscriptions/88b1227e-7e98-41f0-8876-30d8169a818f
pokemon-product-1-0-0-basic-plan    [state: enabled]   https://mgmt.v10.apicww.cloud/api/apps/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/a2880aba-db37-4ea2-b6f1-baa2f813dfde/d029b425-3bcc-473b-a023-ca29adaa5f27/subscriptions/4151606e-6034-48a3-bc56-b4ce3277c115
```

```
$ apic subscriptions:get loopback-product-1-0-0-default -s mgmt.v10.apicww.cloud -o middleearth -c test-cat --consumer-org corg1 -a testapp1

loopback-product-1-0-0-default   loopback-product-1-0-0-default.yaml   https://mgmt.v10.apicww.cloud/api/apps/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/a2880aba-db37-4ea2-b6f1-baa2f813dfde/d029b425-3bcc-473b-a023-ca29adaa5f27/subscriptions/88b1227e-7e98-41f0-8876-30d8169a818f
```

```
type: subscription
api_version: 2.0.0
id: 88b1227e-7e98-41f0-8876-30d8169a818f
name: loopback-product-1-0-0-default
title: loopback-product 1.0.0 default
state: enabled
product_url: >-
  https://mgmt.v10.apicww.cloud/api/catalogs/c6312872-9f34-4f18-b626-b5dbddde87aa/d1330cd6-2ef9-4462-8dca-c2a0384528e4/products/313bd800-7877-438a-91cd-c57d6f5f5ce0
plan: default
plan_title: Default Plan
``` 

Reconstruct `product_url` for target catalog / space: 
* find the owner id from subscription.product_url
* Replace sources with `target_host`, `target_catalog`, `target_space` and `product_name/ver` - 
https://`target_host`/api/catalogs/`target_catalog`/`target_space`/products/`product_name/ver`

```
echo ==========================================================
echo create the subscriptions for app $app in target catalog
echo ==========================================================
# Get all subs from the source app
echo === apic subscriptions:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app
subs=$(apic subscriptions:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app)

subsarray=($subs)
for sub in "${subsarray[@]}"; do
    # apic subscriptions:get $sub -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app
    apic subscriptions:get $sub -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app

    # get product-url from sub file
    prod_id=$(grep \/products\/ $sub.yaml | sed "s|.*/products/||")

    # get prod_name/ver by prod_id from src-prod-name-id.txt
    prod_name_ver=$(grep $prod_id ../../src-prod-name-id.txt | sed "s| .*||" | sed "s|:|/|")

    # if product is not found in src-prod-name-id.txt (i.e. the prod is not published in the given space), skip
    if [ -z "$prod_name_ver" ]; then
        echo === $sub subcribes to a product that is not found in the space $src_space
        continue
    fi
    # Reconstruct `product_url` for target catalog / space:
    target_product_url=https://$target_host/api/catalogs/$target_catalog/$target_space/products/$prod_name_ver
    echo === target product url for sub $sub = $target_product_url

    sed -i "s|https.*products.*|$target_product_url|" $sub.yaml

    # creata the sub in target catalog
    echo === apic subscriptions:create $sub.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg -a $app
    apic subscriptions:create $sub.yaml -s $target_host -o $target_org -c $target_catalog --consumer-org $corg -a $app

done
```

