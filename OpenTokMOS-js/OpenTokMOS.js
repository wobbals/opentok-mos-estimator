function calculateVideoScore(subscriber, stats) {
  var targetBitrateForPixelCount = function(pixelCount) {
    // power function maps resolution to target bitrate, based on rumor config
    // values, with r^2 = 0.98. We're ignoring frame rate, assume 30.
    var y = 2.069924867 * Math.pow(Math.log10(pixelCount), 0.6250223771);
    return Math.pow(10, y);
  }
  
  var MIN_VIDEO_BITRATE = 30000;
  if (stats.length < 2) {
    return 0;
  }
  var currentStats = stats[stats.length - 1];
  var lastStats = stats[stats.length - 2];
  var totalPackets = 
  (currentStats.video.packetsLost + currentStats.video.packetsReceived) -
  (lastStats.video.packetsLost + lastStats.video.packetsReceived);
  var packetLoss =
  (currentStats.video.packetsLost - lastStats.video.packetsLost) / totalPackets;
  var interval = currentStats.timestamp - lastStats.timestamp;
  var bitrate = 8 *
  (currentStats.video.bytesReceived - lastStats.video.bytesReceived) /
  (interval / 1000);
  var pixelCount = subscriber.stream.videoDimensions.width *
  subscriber.stream.videoDimensions.height;
  var targetBitrate = targetBitrateForPixelCount(pixelCount);
  
  if (bitrate < MIN_VIDEO_BITRATE) {
      return 0;
  }
  bitrate = Math.min(bitrate, targetBitrate);
  var score = 
  (Math.log(bitrate / MIN_VIDEO_BITRATE) / 
   Math.log(targetBitrate / MIN_VIDEO_BITRATE)) * 4 + 1
  return score;
}

function calculateAudioScore(subscriber, stats) {
  var audioScore = function(rtt, plr) {
    var LOCAL_DELAY = 20; //20 msecs: typical frame duration
    function H(x) { return (x < 0 ? 0 : 1) }
    var a = 0 // ILBC: a=10
    var b = 19.8
    var c = 29.7
 
    //R = 94.2 − Id − Ie
    var R = function(rtt, packetLoss) {
      var d = rtt + LOCAL_DELAY;
      var Id = 0.024 * d + 0.11 * (d - 177.3) * H(d - 177.3);

      var P = packetLoss;
      var Ie = a + b * Math.log(1 + c * P);

      var R = 94.2 - Id - Ie;
    
      return R;
    }

    //For R < 0: MOS = 1
    //For 0 R 100: MOS = 1 + 0.035 R + 7.10E-6 R(R-60)(100-R)
    //For R > 100: MOS = 4.5
    var MOS = function(R) {
      if (R < 0) {
        return 1;
      }
      if (R > 100) {
        return 4.5;
      }
      return 1 + 0.035 * R + 7.10 / 1000000 * R * (R - 60) * (100 - R);
    }
  
    return MOS(R(rtt, plr));
  }

  if (stats.length < 2) {
      return 0;
  }
  var currentStats = stats[stats.length - 1];
  var lastStats = stats[stats.length - 2];

  var totalAudioPackets =
  (currentStats.audio.packetsLost - lastStats.audio.packetsLost) +
  (currentStats.audio.packetsReceived - lastStats.audio.packetsReceived);
  if (0 == totalAudioPackets) {
      return 0;
  }
  var plr = (currentStats.audio.packetsLost - lastStats.audio.packetsLost) /
  totalAudioPackets;
  // missing from js getStats :-(
  var rtt = 0;
  
  var score = audioScore(rtt, plr);
  return score;
}

function SubscriberMOS(subscriber) {
  var intervalId;
  var statsLog = [];
  var audioScoresLog = [];
  var videoScoresLog = [];
  // this must be at least two, but could be higher to perform further analysis
  var STATS_LOG_LENGTH = 2; 
  // how far back in time would you like to go?
  var SCORES_LOG_LENGTH = 1000;
  var SCORE_INTERVAL = 1000;
  var obj = {};
  obj.audioScore = function() {
    var sum = 0;
    for (var i = 0; i < audioScoresLog.length; i++) {
      var score = audioScoresLog[i];
      sum += score;
    }
    return sum / audioScoresLog.length;
  }
  obj.videoScore = function() {
    var sum = 0;
    for (var i = 0; i < videoScoresLog.length; i++) {
      var score = videoScoresLog[i];
      sum += score;
    }
    return sum / videoScoresLog.length;
  }
  obj.qualityScore = function() {
    return Math.min(obj.audioScore(), obj.videoScore());
  };

  intervalId = window.setInterval(function() {
    subscriber.getStats(function(error, stats) {
      if (!stats) {
        return;
      }
      statsLog.push(stats);
      if (statsLog.length < 2) {
        return;
      }
      
      var videoScore = calculateVideoScore(subscriber, statsLog);
      videoScoresLog.push(videoScore);
      //console.log("videoScore: " + videoScore);
      var audioScore = calculateAudioScore(subscriber, statsLog);
      audioScoresLog.push(audioScore);
      //console.log("audioScore: " + audioScore);
      
      while (statsLog.length > SCORES_LOG_LENGTH) {
        statsLog.shift();
      }
      while (audioScoresLog.length > SCORES_LOG_LENGTH) {
        audioScoresLog.shift();
      }
      while (videoScoresLog.length > SCORES_LOG_LENGTH) {
        videoScoresLog.shift();
      }
    });
  }, SCORE_INTERVAL);
  
  subscriber.on("destroyed", function(event) {
    if (intervalId) {
      window.clearInterval(intervalId);
      intervalId = undefined;
    }
  });

  return obj;
};
