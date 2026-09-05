# Boğaz Kaptanı

Çanakkale–Eceabat arabalı feribot simülasyonu.

## v5 gerçek 3D geçişi
Bu dal, eski native/OpenGL prototipinden Godot 4 tabanlı gerçek 3D yapıya geçiştir. Amaç mobilde yüksek görsel kaliteyi korurken gerçek coğrafya, akıcı deniz, detaylı feribot ve yük dengesi fiziğini tek projede toplamak.

### İlk v5 çekirdeği
- Gerçek koordinat referansları: Çanakkale iskelesi, Eceabat iskelesi, Kilitbahir, Dur Yolcu
- Prosedürel yüksek çözünürlüklü arazi ve kıyı
- Gerstner-benzeri vertex dalgaları + Fresnel tabanlı su shaderı
- Kavisli gövdeli prosedürel feribot
- Mobil render ayarları
- Android debug APK için GitHub Actions

> Not: Bu aşama grafik motoru ve sahne omurgasıdır. Fotogerçekçi son kalite için gerçek glTF/PBR bina, kale, liman ve feribot assetleri bu yapıya eklenir.
