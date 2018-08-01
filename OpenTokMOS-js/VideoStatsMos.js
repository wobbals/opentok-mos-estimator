import moment from 'moment/moment'

export default class VideoStatsMos {
  constructor(videoDimensions) {
    this.statsStartTestTime = 0
    this.statsWindowTestTime = 0
    this.statsLog = []
    this.videoScoreAverage = 0
    if (videoDimensions) {
      this.videoDimensions = videoDimensions
    }
  }

  // how many sample we should consider
  static STATS_LOG_TIME_SAMPLE = 500
  /* output result very SCORE_TIME_WINDOW ex 5000
  by invoking the onVideoStats second argument callback: callbackOutputResult */
  static SCORE_TIME_WINDOW = 5000

  static MIN_VIDEO_BITRATE = 30000
  // how far back in time would you like to go?
  static STATS_LOG_LENGTH = 10

  static targetBitrateForPixelCount = (pixelCount) => {
    // power function maps resolution to target bitrate, based on rumor config
    // values, with r^2 = 0.98. We're ignoring frame rate, assume 30.
    const y = 2.069924867 * (Math.log10(pixelCount) ** 0.6250223771)
    return (10 ** y)
  }

  static calculateVideoScore(currentStats, lastStats) {
    const interval = currentStats.timestamp - lastStats.timestamp
    let bitrate = 8 * (currentStats.video.bytesReceived - lastStats.video.bytesReceived)
    bitrate *= (interval / 1000)

    const pixelCount = this.videoDimensions.width * this.videoDimensions.height
    const targetBitrate = VideoStatsMos.targetBitrateForPixelCount(pixelCount)

    if (bitrate < VideoStatsMos.MIN_VIDEO_BITRATE) {
      return 0
    }
    bitrate = Math.min(bitrate, targetBitrate)
    let score = Math.log(bitrate / VideoStatsMos.MIN_VIDEO_BITRATE) / Math.log(targetBitrate / VideoStatsMos.MIN_VIDEO_BITRATE)
    score = (score * 4) + 1

    return score
  }

  setSubscriberVideoDimension(videoDimensions) {
    this.videoDimensions = videoDimensions
  }

  getVideoScoreAverage() {
    return this.videoScoreAverage
  }

  onVideoStats(subscriberStats, callbackOutputResult) {
    const currentTimeMillis = moment().valueOf()
    if (this.statsStartTestTime === 0) {
      this.statsStartTestTime = currentTimeMillis
      this.statsWindowTestTime = currentTimeMillis
    }

    if ((currentTimeMillis - this.statsStartTestTime) > VideoStatsMos.STATS_LOG_TIME_SAMPLE) {
      const stats = subscriberStats.timestamp ? subscriberStats : {
        ...subscriberStats, timestamp: currentTimeMillis,
      }
      this.statsLog.push(stats)
      if (this.statsLog.length < 2) {
        return
      }
      if (this.statsLog.length > VideoStatsMos.STATS_LOG_LENGTH) {
        this.statsLog.shift()
      }
      this.statsStartTestTime = moment().valueOf()
    }

    if ((currentTimeMillis - this.statsWindowTestTime) > this.SCORE_TIME_WINDOW) {
      const videoScoreAverage = this.statsLog.reduce((a, b) => VideoStatsMos.calculateVideoScore(a, b), 0) / this.statsLog.length
      this.videoScoreAverage = videoScoreAverage
      if (callbackOutputResult) {
        callbackOutputResult(videoScoreAverage)
      }
      this.statsWindowTestTime = moment().valueOf()
    }
  }
}
