import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:videocall/home/agora.dart';

class CamScreen extends StatefulWidget {
  const CamScreen({Key? key}) : super(key: key);

  @override
  State<CamScreen> createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  RtcEngine? engine; // 아고라 관련 엔진
  // 화상 채팅 중의 내 아이디, 임의로 0으로 해놓고 실제 아이디가 들어가면 그걸로 바뀐다.
  int? uid = 0;

  // 상대 id -> 처음엔 필요없음, 영상통화 시작하고 받을 예정.
  int? otherUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live'),
      ),
      body: FutureBuilder<bool>(
        future: init(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    renderMainView(),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        color: Colors.grey,
                        height: 100,
                        width: 100,
                        child: renderSubView(),
                      ),
                    ),
                    renderSubView(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton(
                  onPressed: () async {
                    if (engine != null) {
                      await engine!.leaveChannel();
                      engine = null;
                    }
                  },
                  child: Text('채널나가기'),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  renderMainView() {
    if (uid == null) {
      return Center(
        child: Text('채널에 참여해주세요!'),
      );
    } else {
      //채널에 참여하고 있을 때
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine!,
          canvas: VideoCanvas(
            uid: 0,
          ),
        ),
      );
    }
  }

  renderSubView() {
    if (otherUid == null) {
      return Center(
        child: Text('채널에 유저가 없습니다'),
      );
    } else {
      return AgoraVideoView(
        controller: VideoViewController.remote // remote = 상대방
            (
          rtcEngine: engine!,
          canvas: VideoCanvas(uid: otherUid),
          connection: RtcConnection(channelId: CHANNEL_NAME),
        ),
      );
    }
  }

  Future<bool> init() async {
    final resp = await [Permission.camera, Permission.microphone].request();

    final cameraPermisstion = resp[Permission.camera];
    final microphonePermission = resp[Permission.microphone];

    if (cameraPermisstion != PermissionStatus.granted ||
        microphonePermission != PermissionStatus.granted) {
      throw '카메라 또는 마이크 권한이 없습니다.';
    }
    if (engine == null) {
      engine = createAgoraRtcEngine();

      await engine!.initialize(
        RtcEngineContext(
          appId: APP_ID,
        ),
      );

      engine!.registerEventHandler(
        RtcEngineEventHandler(
            // 내가 채널에 입장했을 때
            // RtcConnection -> 연결정보
            // elapsed -> 연결된 시간 (연결이 얼마나 되었는지)
            onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("채널에 입장했습니다. uid: ${connection.localUid}");
          setState(() {
            uid = connection.localUid;
          });
        },
            //내가 채널에서 나갔을 때
            onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print("채널 퇴장");
          setState(() {
            uid == null;
          });
        },
            // 상대방 유저가 들어왔을 때
            onUserJoined:
                (RtcConnection connection, int remoteUid, int elapsed) {
          print('상대가 채녈에 입장했습니다. otherUid : ${remoteUid}');
          setState(() {
            otherUid = remoteUid;
          });
        }, onUserOffline: (RtcConnection connection, int remoteUid,
                UserOfflineReasonType reason) {
          print('상대가 채녈에서 나갔습니다. otherUid: ${remoteUid}');
          setState(() {
            otherUid = null;
          });
        }),
      );
      // if문 안에 넣어야함. -> 만약에 엔진이 없을 경우 활성화를 시켜야하기 때문에 -> if문안에 없다면 계속 실행하게 되서 오류가 남
      // 엔진이 있으면 오디오를 사용함
      await engine!.enableAudio();
      // 엔진이 있으면 카메라를 사용함
      await engine!.startPreview();

      ChannelMediaOptions options = ChannelMediaOptions();

      await engine!.joinChannel(
          token: TEMP_TOKEN, channelId: CHANNEL_NAME, uid: 0, options: options);
    }
    return true;
  }
}
