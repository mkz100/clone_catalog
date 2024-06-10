#!/bin/bash

ENV=${1:-apic}
function prop {
    grep "${1}" env/${ENV}.properties | cut -d'=' -f2
}

src_host=$(prop 'src_host')
src_user=$(prop 'src_user')
src_pwd=$(prop 'src_pwd')
src_realm=$(prop 'src_realm')

src_org=$(prop 'src_org')
src_catalog=$(prop 'src_catalog')
src_space=$(prop 'src_space')

src_lur=$(prop 'src_lur')

src_prods_dir=$(prop 'src_prods_dir')

target_host=$(prop 'target_host')
target_user=$(prop 'target_user')
target_pwd=$(prop 'target_pwd')
target_realm=$(prop 'target_realm')

target_org=$(prop 'target_org')
target_catalog=$(prop 'target_catalog')
target_space=$(prop 'target_space')

target_lur=$(prop 'target_lur')

# echo $src_host $src_user $src_pwd $src_realm

echo ==========================================================
echo Login src and target API mgr
echo ==========================================================
apic login -s $src_host -u $src_user -p $src_pwd -r $src_realm
apic login -s $target_host -u $target_user -p $target_pwd -r $target_realm

echo ==========================================================
echo clone all products and contained apis from src catalog
echo ==========================================================
rm -rf $src_prods_dir
mkdir $src_prods_dir
cd $src_prods_dir
apic products:clone --scope space -s $src_host -o $src_org -c $src_catalog --space $src_space

echo ==========================================================
echo Publish all products to target catalog / space
echo ==========================================================
prods=$(find . -name "*product_*")
# echo $prods
prodsarray=($prods)
for prod in "${prodsarray[@]}"; do
    # echo $prod
    apic products:publish $prod --scope space -s $target_host -o $target_org -c $target_catalog --space $target_space
done
cd .. #back to parent dir

echo ==========================================================
echo Get all local users from source LUR
echo Remove identity_provider and append the default password to the user yaml
echo Create all local users in target LUR
echo ==========================================================

# get all users from src lur
users=$(apic users:list -s $src_host -o $src_org --user-registry $src_lur | sed "s| .*||")

rm -rf users
mkdir users
cd users
userarray=($users)
for user in "${userarray[@]}"; do
    # echo $prod
    apic users:get $user -s $src_host -o $src_org --user-registry $src_lur

    # remove identity_provider:
    sed -i '/identity_provider/d' $user.yaml

    # append the default password to the user yaml
    echo "password: 7iron-hide" >>$user.yaml

    # create the user in the target LUR
    apic users:create $user.yaml -s $target_host -o $target_org --user-registry $target_lur
done
cd ..

# get product name:ver => id info from source
apic products:list-all --scope space -s $src_host -o $src_org -c $src_catalog --space $src_space >src-prod-name-id.txt

# set catalog setting hash_client_secret=true to allow create credentials with hashed secret
echo === apic catalog-settings:update env/catalog-setting-hash-true.yaml -s $target_host -o $target_org -c $target_catalog
apic catalog-settings:update env/catalog-setting-hash-true.yaml -s $target_host -o $target_org -c $target_catalog

# get all users from src lur
corgs=$(apic consumer-orgs:list -s $src_host -o $src_org -c $src_catalog | sed "s| .*||")

rm -rf corgs
mkdir corgs
cd corgs
corgarray=($corgs)
for corg in "${corgarray[@]}"; do
    echo ==========================================================
    echo create corg $corg in the target catalog $target_catalog
    echo ==========================================================

    # Get cOrgs from source catalog
    echo === apic consumer-orgs:get $corg -s $src_host -o $src_org -c $src_catalog
    apic consumer-orgs:get $corg -s $src_host -o $src_org -c $src_catalog

    # find the owner name of the corg:
    owner_src_id=$(grep users $corg.yaml | sed "s|.*users/||")
    owner_name=$(grep $owner_src_id ../users/* -l | sed "s|.yaml||" | sed "s|.*/||")
    echo === owner id / name: $owner_src_id / $owner_name

    # replace src owner url with target owner url
    target_owner_url=https://$target_host/api/user-registries/$target_org/$target_lur/users/$owner_name
    sed -i "s|https.*users.*|$target_owner_url|" $corg.yaml

    # create the corg in the target catalog
    echo === apic consumer-orgs:create $corg.yaml -s $target_host -o $target_org -c $target_catalog
    apic consumer-orgs:create $corg.yaml -s $target_host -o $target_org -c $target_catalog

    mkdir $corg
    cd $corg
    # get all apps in the corg
    echo === apic apps:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg --space $src_space --space-initiated
    apps=$(apic apps:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg --space $src_space --space-initiated | sed "s| .*||")
    apparray=($apps)
    for app in "${apparray[@]}"; do

        echo ==========================================================
        echo create app $app in the target cOrg $corg
        echo ==========================================================
        # has to create an app dir to hold its own subs. Otherwise, if two apps sub to the same prod, their sub file name clashes.
        mkdir $app
        cd $app

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

        echo ==========================================================
        echo create the subscriptions for app $app in target catalog
        echo ==========================================================
        # Get all subs from the source app
        echo === apic subscriptions:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app
        subs=$(apic subscriptions:list -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app | sed "s| .*||")

        subsarray=($subs)
        for sub in "${subsarray[@]}"; do
            # apic subscriptions:get $sub -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app
            echo === apic subscriptions:get $sub -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app
            apic subscriptions:get $sub -s $src_host -o $src_org -c $src_catalog --consumer-org $corg -a $app

            # get product-url from sub file
            prod_id=$(grep \/products\/ $sub.yaml | sed "s|.*/products/||")

            # get prod_name/ver by prod_id from src-prod-name-id.txt
            prod_name_ver=$(grep $prod_id ../../../src-prod-name-id.txt | sed "s| .*||" | sed "s|:|/|")

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
        cd ..
    done
    cd ..
done
cd ..

# reset catalog setting hash_client_secret=false
echo === apic catalog-settings:update env/catalog-setting-hash-false.yaml -s $target_host -o $target_org -c $target_catalog
apic catalog-settings:update env/catalog-setting-hash-false.yaml -s $target_host -o $target_org -c $target_catalog
