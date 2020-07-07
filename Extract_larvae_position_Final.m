%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Function used to extract successive larvae positions in a series of calibrated pictures subsampled from a movie
%%%% written by Katell GUIZIEN - LECOB - CNRS in August 2019
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
%%%% chemin : path to access the directory containing the series of calibrated pictures
%%%% by default, the output of ffmpeg command used to subsample the movie produces number 
%%%% graphics file named image-xxxx (xxxx being numbers defined in the ffmpeg command)
%%%% while subsampling the movie, care must be taken that camera field view did not change 
%%%% within the subsampled sequence
%%%% plan_couleur : choice for selecting the image colour most appropriate to detect the larvae
%%%% format_video : image format selected on camera (pixel distorsion)
%%%% angle_recadrage : rotation angle to be applied to image when displaying it for scale definition
%%%% inversion_BW : 0 if object are lighter than background / 1 if object are darker than background
%%%% surface_min_larve : minimum surface area in mm2 used to threshold larval projected surface area 
%%%% taille_max_larvae : radius in pixel of the morphing function used to average background (should be bigger than the size of the object the routine should detect)
%%%% taille_min_larvae : minimum number of pixels used to threshold any detected object after binarization
%%%% gray_level : upper value of the range to amplify
%%%% connectivite : connectivity value required in selected object after binarization. It may have the following scalar values:  
%%        4     two-dimensional four-connected neighborhood
%%        8     two-dimensional eight-connected neighborhood
%%%% scale_orient : orientation of the scale on the picture (1: horizontal, 2: vertical)
%%%% scale_size : length of the scale on the picture in the length unit you chose 
%%%% N_larvae : maximum number of larvae to be detected on each image. 
%%%% This number should be the number of larvae on which the experiment was performed
%%%% and is used to filter out rubbish images on which larvae detection failed
%%%% N_image : output the number of successive images on which larvae were detected
%%%% num : output vector with N_image column containing the actual number of larvae detected on each image 
%%%% of the set of N_image successive images
%%%% barycentre : output matrix (2 columns x N_larvae rows x N_image planes) containing (x,y) coordinates 
%%%% of the centroid (column) of the num larvae (row) detected on each image (plane) 
%%%% scale_x/scale_y : scales in metric unit per pixel along x (horizontal in rotated image) and y (vertical) axes 

function [N_image,num,barycentre,scale_x,scale_y]=Extract_larvae_position_Final(chemin,plan_couleur,format_video,angle_recadrage,inversion_BW,surface_max_larve,taille_max_larve,taille_min_larve,gray_level,connectivite,N_larvae)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
numero_initial = input('Number of first image in the series: ');
N_image = input('Number of images to be analyzed: ');

barycentre=zeros(N_larvae,2,N_image);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%lire l'image%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for num1 = numero_initial:N_image+numero_initial-1

if(num1<10)
I = imread([chemin, 'image-000',num2str(num1),'.jpeg']);
elseif(num1<100)
I = imread([chemin,'image-00',num2str(num1),'.jpeg']);
elseif(num1<1000)
I = imread([chemin,'image-0',num2str(num1),'.jpeg']);
else
I = imread([chemin,'image-',num2str(num1),'.jpeg']);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Appliquer une rotation à l'image%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

I = imrotate(I,angle_recadrage);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Definir l'echelle%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(num1==numero_initial)
%%Afficher l'image sur un axe
image(I); axis image
%%Definir l'echelle
id_orientation = input('Select scale orientation (1: Horizontal / 2: Vertical) and click with the mouse on two points that defines the scale : ');
dimension_cuve = ginput(2);

dx = (ceil(dimension_cuve(2,1)) - floor(dimension_cuve(1,1)));
dy =  (ceil(dimension_cuve(2,2)) - floor(dimension_cuve(1,2)));

%%Demander à l'utilisateur les dimensions de la cuve en cm
scale_size = input('Scale size in metric units (cm) : ');

[ny,nx]=size(I(:,:,1));
if(angle_recadrage==0)
ratio=nx/ny/format_video;
elseif(angle_recadrage==-90)
ratio=nx/ny*format_video;
end

if (id_orientation==1)
%%% echelle sur l horizontale cm/pix
scale_x = (scale_size/dx)
%%% echelle sur la verticale cm/pix
scale_y = (scale_size/dx)*ratio
elseif (id_orientation==2)
 %%% echelle sur l horizontale cm/pix
scale_x = (scale_size/dy)/ratio
%%% echelle sur la verticale cm/pix
scale_y = (scale_size/dy)
end

sprintf('Echelle horizontale(cm/px):%30s',scale_x);
sprintf('Echelle verticale(cm/px):%30s',scale_y);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Recadrer l'image%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if(num1==numero_initial)
image(I); axis image
input('Click with the mouse on the upper right and lower left corners of the area that will be analyzed on the image ');
Coord = ginput(2);
llx = floor(Coord(1,1)); %xmin
lly = floor(Coord(1,2)); %ymin
urx = ceil(Coord(2,1)); %xmax
ury = ceil(Coord(2,2)); %ymax
end

%%%%%%%% ATTENTION : les objets recherches doivent etre blancs %%%%%%%%%%%%%%
image_recadre = imcrop (I(:,:,plan_couleur),[llx,lly,urx-llx,ury-lly]);

if(inversion_BW==1)
image_recadreng  = double(255-image_recadre)/255.0;
elseif (inversion_BW==0)
image_recadreng  = double(image_recadre)/255.0;
end 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Appliquer un fond uniforme%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
background = imopen(image_recadreng,strel('disk',taille_max_larve));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Enlever fond de l'image originale%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
I2 = image_recadreng - background;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Augmenter le contraste%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

I2 = imadjust(I2,[0 gray_level],[0 1],3);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Mettre en niveau de gris%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% on fixe la limite blanc/noir arbitrairement pour detecter les larves tres claires
level = graythresh(I2);
I3 = im2bw(I2,level);
I4 = bwareaopen(I3,taille_min_larve,connectivite);

                                                              
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Identifier les objets%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[label,num(num1)] = bwlabel(I4,connectivite);
rgb2 = label2rgb(bwlabel(label,connectivite), 'spring', 'c', 'shuffle');
%imshow(rgb2)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% elimination des gros objets %%%%%%%%%%%%%%%%%%%%%%%%%%%
s = regionprops(label, 'area');
inter = cat(1, s.Area);
[c]=find(inter<surface_max_larve);

if ((length(c)<=N_larvae)&(length(c)>0))
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Barycentre de chaque objet%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	s = regionprops(label, 'centroid');
        num(num1)=length(c);
	inter = cat(1, s.Centroid);
	barycentre(1:size(inter(c,:),1),:,num1) = inter(c,:);
else
	num(num1)=0;
end

end  

end               
