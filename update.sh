#!/bin/bash

declare -a github_repos=("breezy-weather/breezy-weather:Internet")

if [[ ! -d fdroid/metadata ]]; then
	mkdir -p fdroid/metadata
fi

if [[ ! -d fdroid/repo ]]; then
	mkdir -p fdroid/repo
fi

for github_repo in ${github_repos[@]}; do
	description=""

	repo=$(echo $github_repo | sed 's|:.*||')
	wget -q -O latest https://api.github.com/repos/$repo/releases/latest
	release=$(cat latest | grep tag_name | sed 's/.*tag_name\":\ \"//' | sed 's/\",//')
	urls=$(cat latest | grep browser_download_url | sed 's/      "browser_download_url": "//' | sed 's/"//')
	url=$(echo "$urls" | grep .apk$ | grep -v debug | grep -v arm64-v8a | grep -v armeabi-v7a | grep -v x86 | grep -v x86_64)
	asset=$(echo $url | sed 's/.*\///')

	wget -q -O repo https://api.github.com/repos/$repo
	if [[ ! $(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//') == *null* ]]; then
		description=$(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//')
	fi

	wget -q -O fdroid/repo/$asset $url

	name=$(aapt dump badging fdroid/repo/$asset | grep application-label: | sed "s/application-label:'//" | sed "s/'.*//")
	version=$(aapt dump badging fdroid/repo/$asset | grep versionCode | sed "s/.*versionCode='//" | sed "s/'.*//")
	id=$(aapt dump badging fdroid/repo/$asset | grep package:\ name | sed "s/package: name='//" | sed "s/'.*//")

	if [[ -z "$description" ]]; then
		description="$name"
	else
		description="$description"
	fi

	for anti_feature in ${anti_features[@]}; do
		if [[ $(echo $anti_feature | sed 's|:.*||') == $repo  ]]; then
			if [[ ! -f fdroid/metadata/$id.yml ]]; then
				echo "AntiFeatures:" | tee fdroid/metadata/$id.yml
			fi

			if [[ ! $(cat fdroid/metadata/$id.yml | grep $anti_feature) == $anti_feature ]]; then
				echo "    - $(echo $anti_feature | sed 's|.*:||')" | tee -a fdroid/metadata/$id.yml
			fi
		fi
	done

	echo "AuthorName: $(echo $github_repo | sed 's|/.*||')
Categories:
    - $(echo $github_repo | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
Description: |
    $description
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
Summary: \"$(echo $description | cut -c 1-80)\"
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml

	wget -q -O releases https://api.github.com/repos/$repo/releases
	urls=$(cat releases | grep -m1 '"prerelease": true,' -B31 -A224 | grep browser_download_url | sed 's/      "browser_download_url": "//' | sed 's/"//')
	url=$(echo "$urls" | grep .apk$ | grep -v debug | grep -v arm64-v8a | grep -v armeabi-v7a | grep -v x86 | grep -v x86_64)
	asset=$(echo $url | sed 's/.*\///')

	if [[ $(cat releases | grep -m1 '"prerelease": true,' -B31 -A224 | grep created_at -m1 | sed 's/.* "//' | sed 's/T.*//' | sed 's/-//g') -ge $(cat latest | grep created_at -m1 | sed 's/.* "//' | sed 's/T.*//' | sed 's/-//g') ]]; then
		wget -q -O fdroid/repo/$asset $url
	fi

	rm latest

	rm releases

	rm repo

	mkdir -p fdroid/metadata/$id

	git clone https://github.com/$repo

	mv $(echo $repo | sed 's/.*\///')/fastlane/metadata/android/* fdroid/metadata/$id/

	rm -rf $(echo $repo | sed 's/.*\///')

	for folder in fdroid/metadata/$id/*; do
		if [[ -d $folder/images ]]; then
			if [[ -d $folder/images/phoneScreenshots ]]; then
				mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots

				mv $folder/images/phoneScreenshots/* fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots/
			fi

			if [[ -f $folder/images/icon.png ]]; then
				mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')

				mv $folder/images/icon.png fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/
			fi

			rm -rf $folder/images
		fi

		if [[ -d $folder/changelogs ]]; then
			mv $folder/changelogs/default.txt $folder/changelogs/$version.txt
		fi

		if [[ -f $folder/full_description.txt ]]; then
			mv $folder/full_description.txt $folder/description.txt
		fi

		if [[ -f $folder/short_description.txt ]]; then
			mv $folder/short_description.txt $folder/summary.txt
		fi
	done
done

if [[ ! -f fdroid/repo/index-v1.json ]]; then
	echo "{\"repo\": {\"timestamp\": $(date +%s%N | cut -b1-13), \"version\": 20000, \"name\": \"Breezy Weather\", \"icon\": \"icon.png\", \"address\": \"https://julianfairfax.github.io/fdroid-repo/fdroid/repo?fingerprint=83ABB548CAA6F311CE3591DDCA466B65213FD0541352502702B1908F0C84206D\", \"description\": \"The F-Droid repository for Breezy Weather\"}, \"requests\": {\"install\": [], \"uninstall\": []}, \"apps\": [], \"packages\": {}}" | tee fdroid/repo/index-v1.json
fi

cd fdroid

/usr/bin/fdroid update --pretty --delete-unknown

cd ../
