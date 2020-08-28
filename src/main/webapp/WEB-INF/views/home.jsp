<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ page session="false" %>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<html>
<head>
	<title>Home</title>
</head>
<body>

	<!-- Offer -->
	<button id="button" onclick="createOffer()">Offer:</button>
	<textarea id="offer" placeholder="Paste offer here"></textarea>
	
	<!-- Answer -->
	Answer:
	<textarea id="answer"></textarea>
	
	<br>
	
	<!-- 채팅 -->
	<div id="div">
	
	</div>
	
	Chat:
	<input id="chat">
	
	<br><br>
	
	<form id="fileInfo">
		<input type="file" id="fileInput" name="files" />
	</form>
	
	<button disabled id="sendFile">Send</button>
	<button disabled id="abortButton">Abort</button>
	
	<div class="progress">
		<div class="label">Send progress:</div>
		<progress id="sendProgress" max="0" value="0"></progress>
	</div>

	<div class="progress">
		<div class="label">Receive progress:</div>
		<progress id="receiveProgress" max="0" value="0"></progress>
	</div>

	<div id="bitrate"></div>
	<a id="download"></a>
	<span id="status"></span>

	<script>
	
		// var localConnection;
		// var remoteConnection;
		// var sendChannel;
		// var receiveChannel;
		
		var fileReader;

		const config = {iceServers: [{urls: "stun:stun.1.google.com:19302"}]};
		const pc = new RTCPeerConnection(config);
		const dc = pc.createDataChannel("chat", {negotiated: true, id: 0});
		
		const bitrateDiv = document.querySelector('div#bitrate');
		const fileInput = document.querySelector('input#fileInput');
		const abortButton = document.querySelector('button#abortButton');
		const downloadAnchor = document.querySelector('a#download');
		const sendProgress = document.querySelector('progress#sendProgress');
		const receiveProgress = document.querySelector('progress#receiveProgress');
		const statusMessage = document.querySelector('span#status');
		const sendFileButton = document.querySelector('button#sendFile');
		
		var receiveBuffer = [];
		var receivedSize = 0;
		
		var bytesPrev = 0;
		var timestampPrev = 0;
		var timestampStart;
		var statsInterval = null;
		var bitrateMax = 0;
		
		/* 파일 선택 및 파일 선택 */
		fileInput.addEventListener('change', handleFileInputChange, false);
		async function handleFileInputChange() {
			const file = fileInput.files[0];
			
			if(!file) {
				console.log('No file chosen');
			} else {
				sendFileButton.disabled = false;
				alert("file을 보낼 준비가 되었습니다.");
			}
		}
		
		/* Send Button Event */
		sendFileButton.addEventListener("click", () => createConnection());
		async function createConnection() {
			abortButton.disabled = false;
			sendFileButton.disabled = true;
			
			/* localConnection == pc */
// 			localConnection = new RTCPeerConnection();
// 			console.log('Created local peer connection object localConnection');
			
			/* sendChannel == dc */
// 			sendChannel = localConnection.createDataChannel('sendDataChannel');
// 			sendChannel.binaryType = 'arraybuffer';
// 			console.log('Created send data channel');
		
			sendData();
		}
		
		/* sendData() */
		function sendData() {
			const file = fileInput.files[0];
			
			statusMessage.textContent = '';
			downloadAnchor.textContent = '';
			
			if(file.size === 0) {
				bitrateDiv.innerHTML = '';
				statusMessage.textContent = 'File is empty, please select a non-empty file';
				return;
			}
			
			sendProgress.max = file.size;
			receiveProgress.max = file.size;
			
			const chunkSize = 16384;
			fileReader = new FileReader();
			var offset = 0;
			fileReader.addEventListener('error', error => console.error('Error reading file:', error));
			fileReader.addEventListener('abort', event => console.log('File reading aborted:', event));
			fileReader.addEventListener('load', e => {
				console.log('FileRead.onload ', e);
				dc.send(e.target.result);
				offset += e.target.result.byteLength;
				sendProgress.value = offset;
				if (offset < file.size) {
					readSlice(offset);
				}
			});
			const readSlice = o => {
				console.log('readSlice ', o);
				const slice = file.slice(offset, o + chunkSize);
				fileReader.readAsArrayBuffer(slice);
			};
			readSlice(0);
		}
		
	// 	const log = msg => div.innerHTML += `<br>${msg}`;
		/* div(사용자에게 보여지는 textarea)에 메세지 출력 */
		const log = function(msg) {
			div.innerHTML += '<br>' + msg;
		}
		
	// 	dc.onopen = () => chat.select();
		/* 이벤트 발생(상호 연결 완료)시 동작하는 함수 */
		dc.onopen = function() {
			chat.select();
		}
		
	// 	dc.onmessage = e => log(`> ${e.data}`);
		/* 이벤트 발생(메세지 도착)시 동작하는 함수 */
		dc.onmessage = function(e) {
			log(">" + e.data) // message receive
			
			receivedSize = 0;
			bitrateMax = 0;
			downloadAnchor.textContent = '';
			downloadAnchor.removeAttribute('download');
			
			if(downloadAnchor.href) {
				URL.revokeObjectURL(downloadAnchor.href);
				downloadAnchor.removeAttribute('href');
			}
			
			receiveBuffer.push(e.data);
			receivedSize += e.data.byteLength;
			
			receiveProgress.value = receivedSize;
			
			console.log(e.data);
			
// 			const file = fileInput.files[0];
			
// 			if(receivedSize === file.size) {
				const received = new Blob(receiveBuffer);
				receiveBuffer = [];
				
				downloadAnchor.href = URL.createObjectURL(received);
// 				downloadAnchor.download = file.name;
				downloadAnchor.download = "다운로드";
// 				downloadAnchor.textContent = `Click to download '${file.name}'' (${file.size} bytes)`;
				downloadAnchor.textContent = `Click to download`;
				downloadAnchor.style.display = 'block';
				
				const bitrate = Math.round(receivedSize * 8 / ((new Date()).getTime() - timestampStart));
				bitrateDiv.innerHTML = `<strong>Average Bitrate:</strong> ${bitrate} kbits/sec (max: ${bitrateMax} kbits/sec)`;
				
				if(statsInterval) {
					clearInterval(statsInterval);
					statsInterval = null;
				}
// 			}
		}
		
	// 	pc.oniceconnectionstatechange = e => log(pc.iceConnectionState);
		/* 이벤트 발생(커넥션 상태의 변화)시 동작하는 함수 */
		pc.oniceconnectionstatechange = function(e) {
			log(pc.iceConnectionState);
		}
		
		/*  */
		chat.onkeypress = function(e) {
			if (e.keyCode != 13) return;
			dc.send(chat.value); // message send
			log(chat.value); // 
			chat.value = ""; // input-window reset
		};
	
		/* 오퍼 생성 */
		async function createOffer() {
			button.disabled = true;
			await pc.setLocalDescription(await pc.createOffer());
			
			pc.onicecandidate = function(e) {
				if (e.candidate) return;
				offer.value = pc.localDescription.sdp;
				offer.select();
				answer.placeholder = "Paste answer here";
			};
			
		}
		
		offer.onkeypress = async function(e) {
			if (e.keyCode != 13 || pc.signalingState != "stable") return;
			button.disabled = offer.disabled = true;
			await pc.setRemoteDescription({type: "offer", sdp: offer.value});
			await pc.setLocalDescription(await pc.createAnswer());
			
			pc.onicecandidate = ({candidate}) => {
				if (candidate) return;
				answer.focus();
				answer.value = pc.localDescription.sdp;
				answer.select();
			};
		  
		};
		
		answer.onkeypress = function(e) {
			if (e.keyCode != 13 || pc.signalingState != "have-local-offer") return;
			answer.disabled = true;
			pc.setRemoteDescription({type: "answer", sdp: answer.value});
		};

	</script>

</body>
</html>
