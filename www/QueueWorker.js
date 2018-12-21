/**
 * A Queue worker for the Image cache plugin for Cordova
 *
 * Developed by Daniil Kostin
 */

function QueueWorker() {}

var workQueue = [];
var workQueueSuccessTasks = [];
var workQueueKeys = {};
var isWorkerWorking = false;

// var runcount = 0;

var QueueDelay = 0;

QueueWorker.prototype.execute = function () {
  //console.log("getQueue", getQueue, getQueue.length)
  if (!workQueue.length) {
    isWorkerWorking = false;
    // console.log('workQueueSuccessTasks', workQueueSuccessTasks);
    // console.log('total executes', runcount);
    // runcount = 0;
    return;
  }

  // runcount++;
  // console.log('execute -> runcout:', runcount)

  isWorkerWorking = true;
  var task = workQueue.shift();

  //console.log("task", task)

  if (typeof task.task === 'function') {
    task.task(function (url) {
      // console.log('task success -> key:', task.key, ' url: ', url);
      queueWorker.onKeySuccess(task.key, url);

      workQueueSuccessTasks = workQueueSuccessTasks.filter(function (value) { return value !== task.key; });

      if (QueueDelay > 0) setTimeout(queueWorker.execute, QueueDelay);
      else queueWorker.execute();
    }, function (err) {
      // console.log('task error -> key:', task.key);
      queueWorker.onKeyError(task.key, err);

      workQueueSuccessTasks = workQueueSuccessTasks.filter(function (value) { return value !== task.key; });

      if (QueueDelay > 0) setTimeout(queueWorker.execute, QueueDelay);
      else queueWorker.execute();
    })
  }
}

QueueWorker.prototype.addTask = function (key, timestamp, task, successCallback, errorCallback) {
  if (!workQueueKeys[key]) {
    // console.log('new task -> key:', key);

    if (typeof task  === 'function') {
      workQueueKeys[key] = {
        timestamp: timestamp,
        onSuccess: [successCallback],
        onError: [errorCallback]
      };

      workQueue.push({
        task: task,
        key: key
      });

      workQueueSuccessTasks.push(key);
    } else {
      console.error('QueueWorker.prototype.addTask supports types: function. You try type:' + typeof task);
      return;
    }

    if (!isWorkerWorking) {
      this.execute();
    }
  } else {
    // console.log('old task -> key:', key)

    workQueueKeys[key].timestamp = timestamp;
    workQueueKeys[key].onSuccess.push(successCallback);
    workQueueKeys[key].onError.push(errorCallback);
  }
}

QueueWorker.prototype.onKeySuccess = function (key, url) {
  if (workQueueKeys[key] && Array.isArray(workQueueKeys[key].onSuccess)) {
    workQueueKeys[key].onSuccess.forEach(function (callback) {
      if (typeof callback === 'function') {
        callback(url);
      }
    })

    delete workQueueKeys[key];
  }
}

QueueWorker.prototype.onKeyError = function (key, err) {
  if (workQueueKeys[key] && Array.isArray(workQueueKeys[key].onError)) {
    workQueueKeys[key].onError.forEach(function (callback) {
      if (typeof callback === 'function') {
        callback(err);
      }
    })

    delete workQueueKeys[key];
  }
}

var queueWorker = new QueueWorker();

module.exports = queueWorker;
