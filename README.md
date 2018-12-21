# Cordova Image Cache plugin

Native Image Cache plugin for iOS and Android.

This plugin do not require any permissions or dependencies. It uses temporary folders to store binary representation of your images with timestamps. If timestamps are greater it stores a new image version. Plugin has two levels of cache in browser ram and on the device for increase loading speed.


# Install
```
cordova plugin add com.danleech.cordova.plugin.imagecache
```

# Usage

#### Simple:
```js
let p = new Promise((resolve, reject) => {
  cordova.plugins.ImageCache.get(imageUrl, timestamp, resolve, () => {
    cordova.plugins.ImageCache.store(imageUrl, timestamp, imageUrl, resolve, reject);
  });
});

p.then(url => {
  // already loaded image url
  let img = new Image();
  img.src = url;
})
```
#### Firebase Storage
```js
let p = new Promise((resolve, reject) => {
  cordova.plugins.ImageCache.get(imageKey, timestamp, resolve, () => {
    firebase.storage().refFromURL(imageKey).getDownloadURL()
        .catch(err => {
          reject(err);
        })
        .then(url => {
          cordova.plugins.ImageCache.store(imageKey, timestamp, url, resolve, reject);
        });
  });
});
```

# License
Project is available under the MIT license. See the LICENSE file for more info.
