# ImageAuthenticator Smart Contract

`ImageAuthenticator`는 이미지의 `pHash`를 온체인에 등록하고, 등록자 주소와 판매 가격을 함께 관리하는 Solidity 컨트랙트입니다.  
이미지가 이미 등록되어 있는지 확인하고, 소유자가 가격을 수정하고, 구매자가 지정된 금액을 전송하는 흐름을 제공합니다.

현재 구현 기준으로 `purchaseImage()`는 결제를 기존 등록자에게 전달합니다. README 아래 설명도 이 실제 동작 기준으로 정리되어 있습니다.

## Features

- 이미지 `pHash`를 중복 없이 등록
- 등록한 주소를 이미지 소유자로 저장
- 이미지별 판매 가격 저장 및 수정
- 구매 시 정확한 금액만 허용하고 판매자에게 직접 송금
- 조회 함수로 등록 여부, 소유자, 가격, 저장된 데이터 확인


## Contract Overview

주요 저장 구조는 아래와 같습니다.

- `images`: `pHash`별 `ImageData` 저장
- `imageOwners`: `pHash`별 등록자 주소 저장
- `imagePrices`: `pHash`별 판매 가격 저장

`ImageData` 구조체는 현재 아래 필드만 포함합니다.

```solidity
struct ImageData {
    string pHash;
}
```

## Core Functions

### `registerImage(string pHash, uint256 price)`

새로운 이미지 해시를 등록합니다.

- 빈 `pHash`는 허용되지 않습니다.
- `price`는 0보다 커야 합니다.
- 이미 등록된 `pHash`는 다시 등록할 수 없습니다.
- 호출한 주소가 해당 이미지의 소유자로 저장됩니다.
- 등록 성공 시 `ImageRegistered` 이벤트가 발생합니다.

사용 목적:
- 이미지의 지문값을 기준으로 원본 등록 이력을 남기고 싶을 때
- 이미지별 판매 가격을 최초 설정하고 싶을 때

### `updatePrice(string pHash, uint256 newPrice)`

이미 등록된 이미지의 판매 가격을 변경합니다.

- 등록된 이미지에만 호출할 수 있습니다.
- 현재 소유자만 가격을 변경할 수 있습니다.
- `newPrice`는 0보다 커야 합니다.
- 변경 성공 시 이전 가격과 새 가격이 함께 `ImagePriceUpdated` 이벤트에 기록됩니다.

### `purchaseImage(string pHash)`

이미지 구매 결제를 처리합니다.

- 등록된 이미지에만 호출할 수 있습니다.
- 현재 소유자는 자기 이미지를 직접 구매할 수 없습니다.
- `msg.value`가 저장된 가격과 정확히 일치해야 합니다.
- 결제 금액은 현재 소유자에게 즉시 전달됩니다.
- 성공 시 `ImagePurchased` 이벤트가 발생합니다.


### `getImage(string pHash)`

이미지의 소유자와 가격을 한 번에 조회합니다.

반환값:
- `owner`: 현재 등록된 소유자 주소
- `price`: 현재 판매 가격

### `getImageData(string pHash)`

해당 이미지의 `ImageData` 구조체 전체를 반환합니다.

현재는 `pHash`만 return 합니다.

### `getOwner(string pHash)`

phash 기준 이미지의 현재 등록 소유자 주소를 반환합니다.

### `getPrice(string pHash)`

phash 기준 이미지의 현재 판매 가격을 반환합니다.

### `isRegistered(string pHash)`

해당 `pHash`가 이미 등록되어 있는지 `true/false`로 반환합니다.

프론트엔드나 스크립트에서 등록 전 중복 체크를 할 때 유용합니다.

## Modifiers

### `onlyRegistered(string pHash)`

이미지가 등록되어 있는 경우에만 함수 실행을 허용합니다.

적용 함수:
- `updatePrice`
- `purchaseImage`
- `getImage`
- `getImageData`
- `getOwner`
- `getPrice`

### `onlyImageOwner(string pHash)`

현재 호출자가 해당 이미지의 소유자인 경우에만 함수 실행을 허용합니다.

적용 함수:
- `updatePrice`

## Events

### `ImageRegistered`

이미지 등록 시 발생합니다.

- `owner`
- `pHash`
- `price`
- `timestamp`

### `ImagePriceUpdated`

가격 변경 시 발생합니다.

- `owner`
- `pHash`
- `oldPrice`
- `newPrice`
- `timestamp`

### `ImagePurchased`

구매 결제 성공 시 발생합니다.

- `buyer`
- `owner`
- `pHash`
- `amount`
- `timestamp`

## Custom Errors

- `EmptyPHash`: 빈 `pHash`로 등록 시도
- `InvalidPrice`: 가격이 0인 경우
- `ImageAlreadyRegistered`: 이미 등록된 `pHash`를 다시 등록하려는 경우
- `ImageNotRegistered`: 등록되지 않은 이미지에 접근하는 경우
- `NotImageOwner`: 소유자가 아닌 계정이 가격 변경을 시도하는 경우
- `IncorrectPayment(expected, received)`: 전송한 금액이 저장된 가격과 다른 경우
- `OwnerCannotPurchaseOwnImage`: 소유자가 자기 이미지를 구매하려는 경우
- `PaymentTransferFailed`: 판매자에게 ETH 송금이 실패한 경우

## 배포된 컨트랙트 주소

0x6154ab54f64106e00C715EBfC7cE6ce8C5dfF9CB


## ABI 경로

ignition/deployments/image-authenticator-20260423/artifacts/ImageAuthenticatorModule#ImageAuthenticator.json 

JSON 다운로드 이후에 abi 추출해서 사용하시면 됩니다.

백엔드 기준 ether.js flutter 기준 web3dart   
