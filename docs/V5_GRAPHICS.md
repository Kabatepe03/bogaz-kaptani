# v5 gerçek 3D grafik planı

## Bu committe
1. Godot 4 Mobile renderer tabanı
2. Gerçek dünya koordinatlarını metre tabanlı yerel sahneye çevirme
3. Çanakkale/Eceabat iki yakalı prosedürel arazi
4. Vertex dalgalı, Fresnel yansımalı su shaderı
5. Kavisli kesitlerden üretilen feribot gövdesi
6. Köprüüstü, cam bandı, güverte, rampalar ve kamera noktaları
7. Android ARM64 otomatik debug build workflow

## Sıradaki grafik paketi
- Gerçek DEM yükseklik verisi ile kıyı/dağ meshleri
- OSM tabanlı gerçek yol ve bina ayak izleri
- Fotogrametri/PBR referanslı Çanakkale iskele, Eceabat iskele, Kilitbahir ve Dur Yolcu modelleri
- Feribot için UV açılmış glTF/PBR model (albedo/normal/roughness/metallic)
- Kıyı köpüğü, wake trail, pervane izi ve su derinlik rengi
- LOD/HLOD, occlusion ve mobil 30/60 FPS profilleri

## Kalite kuralı
Eski prototipteki kutu/lego geometriler final asset olarak kabul edilmeyecek. Prosedürel yapılar sadece dünya ölçeği, rota ve performans testinde placeholder olarak kullanılacak; final görünüm glTF/PBR assetlerle değiştirilecek.
