//
//  OTSubscriberMOS.m
//  OpenTokMOS
//
//  Created by Charley Robinson on 12/5/16.
//  Copyright © 2016 TokBox, Inc. All rights reserved.
//

#import "OTSubscriberMOS.h"

@protocol OTStatsCollector <NSObject>
- (int64_t)videoSSRC;
- (int64_t)audioSSRC;
- (NSString*)statForKey:(NSString*)key
            lastUpdated:(struct timeval*)lastUpdated;
- (NSArray*)statsKeys;
@end

@interface OTSubscriberKit() <OTStatsCollector>
@end

@implementation OTSubscriberMOS {
    NSMutableArray* _audioStats;
    NSMutableArray* _videoStats;
    NSMutableArray* _videoScores;
    NSMutableArray* _audioScores;
    __weak OTSubscriberKit* _subscriber;
}

- (instancetype)initWithSubscriber:(OTSubscriberKit*)subscriber
{
    self = [super init];
    if (self) {
        _subscriber = subscriber;
        [_subscriber setNetworkStatsDelegate:self];
        _videoStats = [NSMutableArray new];
        _audioStats = [NSMutableArray new];
        _videoScores = [NSMutableArray new];
        _audioScores = [NSMutableArray new];
    }
    return self;
}

// retention for raw stats needs to be at least big enough to view the last two,
// but you could keep more for other purposes
#define MAX_STATS_KEPT 2
#define SCORE_HEARTBEAT_INTERVAL_MS 30000
#define MAX_SCORES_KEPT INT_MAX

- (void)prune {
    while (_audioStats.count > MAX_STATS_KEPT) {
        [_audioStats removeObjectAtIndex:0];
    }
    while (_videoStats.count > MAX_STATS_KEPT) {
        [_videoStats removeObjectAtIndex:0];
    }
    while (_videoScores.count > MAX_SCORES_KEPT) {
        [_videoScores removeObjectAtIndex:0];
    }
    while (_audioScores.count > MAX_SCORES_KEPT) {
        [_audioScores removeObjectAtIndex:0];
    }
}

- (void)subscriber:(OTSubscriberKit*)subscriber
videoNetworkStatsUpdated:(OTSubscriberKitVideoNetworkStats*)stats
{
    OTSubscriberKitVideoNetworkStats* lastStats = _videoStats.lastObject;
    if (stats.timestamp - lastStats.timestamp < SCORE_HEARTBEAT_INTERVAL_MS ) {
        return;
    }
    [_videoStats addObject:stats];
    [self calculateVideoScore];
    [self prune];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
audioNetworkStatsUpdated:(OTSubscriberKitAudioNetworkStats*)stats
{
    OTSubscriberKitAudioNetworkStats* lastStats = _audioStats.lastObject;
    if (stats.timestamp - lastStats.timestamp < SCORE_HEARTBEAT_INTERVAL_MS ) {
        return;
    }
    [_audioStats addObject:stats];
    [self calculateAudioScore];
    [self prune];
}

#define MIN_VIDEO_BITRATE 30000

- (double)calculateVideoScore
{
    if (_videoStats.count < 2) {
        return 0;
    }
    OTSubscriberKitVideoNetworkStats* currentStats = _videoStats.lastObject;
    OTSubscriberKitVideoNetworkStats* lastStats =
    [_videoStats objectAtIndex:_videoStats.count - 2];
    NSTimeInterval interval = currentStats.timestamp - lastStats.timestamp;

    double bytesIn =
    currentStats.videoBytesReceived - lastStats.videoBytesReceived;
    double bitrate = (bytesIn * 8) / (interval / 1000);
    // Discard bitrates below a reasonable floor
    if (bitrate < MIN_VIDEO_BITRATE) {
        return 0;
    }
    // Cap the bitrate by a reasonable ceiling
    NSInteger pixelCount =
    _subscriber.stream.videoDimensions.height *
    _subscriber.stream.videoDimensions.width;
    double targetBitrate = [self targetBitrateForPixelCount:pixelCount];
    bitrate = MIN(targetBitrate, bitrate);

    double score =
    (log(bitrate / MIN_VIDEO_BITRATE) /
     log(targetBitrate / MIN_VIDEO_BITRATE)) * 4 + 1;

    [_videoScores addObject:[NSNumber numberWithDouble:score]];
    return score;
}

- (double)targetBitrateForPixelCount:(double)numPixels
{
    // power function derived from rumor maxbitrate configuration with r^2=0.987
    // assuming a constant 30 fps, although we don't actually check :-/
    double y = 2.069924867 * pow(log10(numPixels), 0.6250223771);
    return pow(10, y);
}

- (double)calculateAudioScore
{
    if (_audioStats.count < 2) {
        return 0;
    }
    OTSubscriberKitAudioNetworkStats* currentStats = _audioStats.lastObject;
    OTSubscriberKitAudioNetworkStats* lastStats =
    [_audioStats objectAtIndex:_audioStats.count - 2];

    NSInteger totalAudioPackets =
    (currentStats.audioPacketsLost - lastStats.audioPacketsLost) +
    (currentStats.audioPacketsReceived - lastStats.audioPacketsReceived);
    if (0 == totalAudioPackets) {
        return 0;
    }
    double plr = (currentStats.audioPacketsLost - lastStats.audioPacketsLost) /
    totalAudioPackets;

    // rtt is not passed in the stats callbacks, so we cheat and ask webrtc
    NSString* rttKey = @"googCandidatePair.Channel-audio-1.googRtt";
    NSString* rttStr = [_subscriber statForKey:rttKey lastUpdated:nil];
    NSInteger rtt = rttStr.integerValue;

    double score = audioMOS(R(rtt, plr));
    [_audioScores addObject:[NSNumber numberWithDouble:score]];
    return score;
}

- (double)videoScore
{
    double sum = 0;
    for (NSNumber* number in _videoScores) {
        sum += number.doubleValue;
    }
    return sum / _videoScores.count;
}

- (double)audioScore
{
    double sum = 0;
    for (NSNumber* number in _audioScores) {
        sum += number.doubleValue;
    }
    return sum / _audioScores.count;
}

- (double)qualityScore
{
    return MIN([self audioScore], [self videoScore]);
}

#define LOCAL_DELAY 20; //20 msecs: typical frame duration
#define H(x) (x < 0 ? 0 : 1)
#define a 0 // ILBC: a=10
#define b 19.8
#define c 29.7

//R = 94.2 − Id − Ie
double R(double rtt, double packetLoss) {
    double d = rtt + LOCAL_DELAY;
    double Id = 0.024 * d + 0.11 * (d - 177.3) * H(d - 177.3);

    double P = packetLoss;
    double Ie = a + b * log(1 + c * P);

    double R = 94.2 - Id - Ie;
    
    return R;
}

//For R < 0: MOS = 1
//For 0 R 100: MOS = 1 + 0.035 R + 7.10E-6 R(R-60)(100-R)
//For R > 100: MOS = 4.5
double audioMOS(double R) {
    if (R < 0) {
        return 1;
    }
    if (R > 100) {
        return 4.5;
    }
    return 1 + 0.035 * R + 7.10 / 1000000 * R * (R - 60) * (100 - R);
}

@end
