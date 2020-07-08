%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Function used to measure larval projected surface area (2D) from calibrated pictures
%%%% written by Katell GUIZIEN - LECOB - CNRS in August 2019
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
%%%% nom_fic : filename of the picture file
%%%% chemin : path to access the directory containing the picture file
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
%%%% surface : projected surface area of all larvae detected on the picture scaled in the square of length unit selected above

function [surface]=SurfaceObjetFinal(nom_fic,chemin,plan_couleur,format_video,angle_recadrage,inversion_BW,surface_min_larve,taille_max_larve,taille_min_larve,gray_level,connectivite,scale_orient, scale_size)

%plan_couleur = 1
%format_video=4/3;
%angle_recadrage=0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% upload the graphics file %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

I=imread([chemin,nom_fic]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% define the scale %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% display image
image(I); axis image
%% define scale on picture
id_orientation = scale_orient;
sprintf('Define scale with the mouse (click each extremity of the scale once) : ');
dimension_cuve = ginput(2);

dx = (ceil(dimension_cuve(2,1)) - floor(dimension_cuve(1,1)));
dy =  (ceil(dimension_cuve(2,2)) - floor(dimension_cuve(1,2)));


[ny,nx]=size(I(:,:,1));
if(angle_recadrage==0)
ratio=nx/ny/format_video;
elseif(angle_recadrage==90)
ratio=nx/ny*format_video;
end

if (id_orientation==1)
%%% horizontal scale length/pix
echelle_x = (scale_size/dx)
%%% vertical scale length/pix
echelle_y = (scale_size/dx)*ratio
elseif (id_orientation==2)
%%% horizontal scale cm/pix
echelle_x = (scale_size/dy)/ratio
%%% vertical scale cm/pix
echelle_y = (scale_size/dy)
end

sprintf('Horizontal scale (mm/px):%30s',echelle_x);
sprintf('Vertical scale (mm/px):%30s',echelle_y);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Recadrer l'image%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

image(I); axis image
sprintf('Define upper right and lower left corner to be processed (where objects are!) : ');
Coord = ginput(2);
llx = floor(Coord(1,1)); %xmin
lly = floor(Coord(1,2)); %ymin
urx = ceil(Coord(2,1)); %xmax
ury = ceil(Coord(2,2)); %ymax


%%%%%%%% ATTENTION : seeked objects should be white %%%%%%%%%%%%%%
image_recadre = imcrop (I(:,:,plan_couleur),[llx,lly,urx-llx,ury-lly]);

if(inversion_BW==1)
image_recadreng  = double(255-image_recadre)/255.0;
elseif (inversion_BW==0)
image_recadreng  = double(image_recadre)/255.0;
end 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% compute the background %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

background = imopen(image_recadreng,strel('disk',taille_max_larve));
imshow(background);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% remove background from original image %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

I2 = image_recadreng - background;
%imshow(I2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% increase contrast %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

I2 = imadjust(I2,[0 gray_level],[0 1],3);
imshow(I2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% apply gray treshold to binarize image %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% threshold is an entry parameter defined to detect light grey larvae 
level = graythresh(I2);
I3 = im2bw(I2,level);
I4 = bwareaopen(I3,taille_min_larve,connectivite);
imshow(I4);
                                                              
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% identify objects %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[label,num] = bwlabel(I4,connectivite);
rgb2 = label2rgb(bwlabel(label,connectivite), 'spring', 'c', 'shuffle');
%imshow(rgb2)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% remove small artefactual objects or truncated larvae %%%%%%%%%%%%%%%%%%%%%%%%%%%
s = regionprops(label, 'area');
inter = cat(1, s.Area);
[c]=find(inter>surface_min_larve);

surface=inter(c)*echelle_x^2;

end

