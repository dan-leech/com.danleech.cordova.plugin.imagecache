/**
 * An Image cache plugin for Cordova
 *
 * Developed by Daniil Kostin
 */

var QueueWorker = require('./QueueWorker');

function ImageCache() {
}

var storage = {};

/**
 * @param string key
 * @param int timestamp
 * @param string|blob url
 */
ImageCache.prototype.store = function (key, timestamp, source, successCallback, errorCallback) {
  if (source) {
    function processSource(blob) {
      // console.log('ImageCache.prototype.store key:', key);
      storeBlobToDevice(key, timestamp, blob, function (url) {
        // console.log('<- storeBlobToDevice -> key:', key, ' url:', url)
        if (typeof successCallback === 'function')
          successCallback(url);
      }, function (err) {
        if (typeof errorCallback === 'function')
          errorCallback(err)
      });
    }

    if (typeof source === 'string') {
      getFileBlobByUrl(source).then(function (blob) {
        processSource(blob);
      }).catch(function (err) {
        console.error(err);
      })
    } else if (source instanceof Blob) {
      processSource(source);
    } else {
      if (typeof errorCallback === 'function')
        errorCallback(new Error('source(' + (typeof source) + ') is not supported'));
    }
  }
};

/**
 * @param string key
 * @param int timestamp
 * @return string url
 */
ImageCache.prototype.get = function (key, timestamp, successCallback, errorCallback) {
  if (key) {
    var url = getUrl(key, timestamp);
    // console.log('ImageCache.prototype.get -> browser url:', url, ' key:', key)
    if (url) {
      if (typeof successCallback === 'function')
        successCallback(url);
    } else {
      // try to get blob from device
      var tries = 0;

      // console.log('ImageCache.prototype.get -> getCall - tries:', tries, ' key:', key)
      QueueWorker.addTask('get_' + key, timestamp, function (taskSuccess, taskError) {
        var getCall = function () {
          cordova.exec(function (data) {
            // console.log('ImageCache.prototype.get -> getCall - data:', data, ' key:', key)
            if (!data || !data.imageData) {
              taskError(new Error('get empty data.imageData'));
              return;
            }

            var byteArray = new Uint8Array(data.imageData);
            var blob = new Blob([byteArray], {type: data.mimeType});

            // store to window buffer
            storeItem(key, timestamp, blob).then(taskSuccess).catch(taskError);
          }, function (err) {
            // console.log('ImageCache.prototype.get -> getCall - err', err, ' key:', key);
            if (err === 'eof' && tries < 3) {
              setTimeout(getCall, 1000);
            } else {
              taskError(err);
            }
          }, "ImageCachePlugin", "getKey", [key, timestamp || 0]);

          tries++;
        }

        getCall();
      }, successCallback, errorCallback)
    }
  } else {
    if (typeof errorCallback === 'function')
      errorCallback(url);
  }
};

function storeItem(key, timestamp, blob) {
  return new Promise(function (resolve, reject) {
    removeItem(key);

    storage[key] = {
      timestamp: timestamp,
      blob: blob,
      url: URL.createObjectURL(blob)
    };

    var img = new Image();

    img.onload = function () {
      // console.log('storeItem -> img.onload -> key:', key, ' url: ', storage[key].url);
      resolve(storage[key].url);
    };
    img.onerror = function () {
      reject(new Error('Can\'t load image ' + url));
    };

    // console.log('storeItem -> key:', key, ' url: ', storage[key].url)
    img.src = storage[key].url;
  });
}

function removeItem(key) {
  if (storage[key]) {
    URL.revokeObjectURL(storage[key].url);
    delete storage[key];
  }
}

function getUrl(key, timestamp) {
  return typeof storage[key] === 'object' && storage[key].timestamp === timestamp ? storage[key].url : null
}

function storeBlobToDevice(key, timestamp, blob, successCallback, errorCallback) {
  QueueWorker.addTask('write_' + key, timestamp, function (taskSuccess, taskError) {
    var fileReader = new FileReader();

    var offset = 0;
    var count = 0;
    const BLOCK_SIZE = 1 * 1024 * 1024; // write blocks of 1MB at a time
    // console.log('ImageCache storeBlobToDevice -> writeNext  blob.size:', blob.size, ' key:', key)

    var onWriteNextError = function (err) {
      console.log('ImageCache Plugin -> onWriteNextError - err:', err, ' key:', key);
      taskError(err);
    }

    var writeNext = function (finishCallback) {
      if (offset >= blob.size) {
        finishCallback();
        return;
      }

      var blockSize = Math.min(BLOCK_SIZE, blob.size - offset);
      var block = blob.slice(offset, offset + blockSize);
      // console.log('ImageCache storeBlobToDevice -> writeNext  offset:', offset, ' run count:', count, ' key:', key)
      count++;

      var onWriteEnded = function () {
        if (offset < blob.size) {
          offset += blockSize;
          writeNext(finishCallback);
        } else {
          finishCallback();
        }
      };

      fileReader.onload = function () {
        // Pending Blob Read Result
        data = new Uint8Array(this.result);

        // store blob to device
        if (offset === 0) { // create file
          cordova.exec(onWriteEnded, onWriteNextError, "ImageCachePlugin", "storeKey", [key, timestamp || 0, data, blob.type, blob.size]);
        } else { // append file
          cordova.exec(onWriteEnded, onWriteNextError, "ImageCachePlugin", "appendKey", [key, data, offset]);
        }
      };

      fileReader.onerror = function () {
        console.log('ImageCache Plugin -> fileReader.onerror:', this.error, ' key:', key);
        taskError(this.error);
      };

      fileReader.readAsArrayBuffer(block);
    };

    // run write task
    writeNext(function () {
      // console.log('ImageCache -> File writing finished - key:', key);
      // store to window buffer
      storeItem(key, timestamp, blob).then(taskSuccess).catch(taskError);
    });
	}, successCallback, errorCallback);
}

function getFileBlobByUrl (url) {
  return new Promise(function (resolve, reject) {
    var xhr = new XMLHttpRequest();

    xhr.responseType = 'blob';
    xhr.timeout = 5000;

    xhr.onload = function () {
      if (xhr.response != null && xhr.response.size > 0) { // ios hack
        resolve(xhr.response);
      } else if (xhr.status === 200) {
        resolve(xhr.response);
      } else {
        reject(xhr);
      }
    }
    xhr.ontimeout = function () {
      console.error('The request for ' + url + ' timed out.');
      reject(new Error('File request timeout'));
    }

    xhr.open('GET', url);
    xhr.send();
  })
}


var imageCache = new ImageCache();

module.exports = imageCache;
