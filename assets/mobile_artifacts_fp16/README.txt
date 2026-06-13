파일											역할
manifest.json						어떤 모델/encoder/precision 파일을 써야 하는지 알려주는 목록
preprocessing.json					이미지 입력 전처리 정보. resize, normalize 기준
tokenizer.json						텍스트 검색 때 어떤 tokenizer 기준을 써야 하는지 설명
classes.json							모델이 구분하는 landmark id 목록
labels_master.json					클래스 개수와 class 목록 요약
prototype_index.json					이미지 검색에서 비교할 landmark 대표 embedding
config.yaml							학습 당시 모델/config 기록
*_image_encoder_fp16_mixed.onnx			이미지 입력을 512차원 embedding으로 바꾸는 모델
*_image_encoder_fp16_mixed.onnx.data		image encoder 가중치 데이터. 반드시 ONNX와 함께 필요
*_text_encoder_fp16_mixed.onnx			text token 입력을 512차원 embedding으로 바꾸는 모델
*_text_encoder_fp16_mixed.onnx.data		text encoder 가중치 데이터. 반드시 ONNX와 함께 필요

(* 는 모델명을 의미함)