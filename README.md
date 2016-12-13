# OpenTok MOS Estimator

## Background

Each OpenTok client SDK includes network stats callbacks on the subscriber to
allow programmatic access to a subset of the WebRTC getStats dictionary. While
the stats seem interesting on their own, this project aims to digest available
getStats data into a single, simple to use metric, a numerical 1-5 estimate
of the mean opinion score (MOS) of a given subscriber. This data differs from
other existing tools by being made available on-demand, in real-time, and on
the endpoint, rather than through a server-side data process.


## Usage

Specific usage details for each platform SDK are available in respective
subproject directories. Overall, the workflow is the same for each -- a new
module is introduced to either subtype or attach to a normal OpenTok
Subscriber.

## Notes

* Scoring algorithm is loosely based on the ITU-T E-model.

* Audio scores are calculated as primarily a function of packet loss, and RTT 
is gathered when possible, depending on platform availability.

* Video scores are calculated primarily as a function of bitrate, where
target bitrates are considered based on the assumed resolution of received
video. Low resolution video does not currently incur a score penalty, although
there are compelling reasons for doing so.

* Both scores are calculated periodically (configurable), and a requested score
is given as the mean of all calculated scores. An overall score for the
subscriber is the minimum of the two audio/video scores, or whatever is
available for the stream. 

* Streams with hasAudio or hasVideo == false will not have scores calculated
for those tracks, and will not take a penalty. In these cases, the only
available score is presented as the overall score for the subscriber.
