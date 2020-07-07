%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Function used to build larval track from successive larvae positions in a series of 
%%%% calibrated pictures subsampled from a movie
%%%% written by Katell GUIZIEN - LECOB - CNRS in August 2019
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
%%%% N_image : number of successive images on which larvae were detected
%%%% num : vector with nbimage columns containing the actual number of larvae detected on each image of the set of successive images
%%%% barycentre : matrix (2 columns x N_larvae rows x nbimage planes) containing (x,y) coordinates of the centroid (column)
%%%% of the num larvae (row) detected on each image (plane)
%%%% scale_x/scale_y : scales in metric unit per pixel along x (horizontal in rotated image) and y (vertical) axes 
%%%% dt : sampling time step used in ffmpeg command when subsampling the movie into graphics file
%%%% max_speed: maximum vertical speed expected for a larvae (used to filter out unrealistic jumps in tracks 
%%%% and tracks of undesired moving objects such as insects)
%%%% N_file : number of output files containing tracks produced

function [N_file]=Build_track_Final(N_image,num,barycentre,scale_x,scale_y,dt,max_speed)

%%%%%%%%%%%%%%%%%%%%%%%%Parametres%%%%%%%%%%%%%%%%%%%%%%
%dt =0.5
%max_speed=1.5%% cm/s
deplacement_max=max_speed/scale_y*dt

%%% seek for images in which no larvae was detected
ind_test=find(num==0)


if length(ind_test)>0
%%% if any, slot tracks detection over a range of successive images on which larvae where detected
%%% ind_debut = indices of first image of the range
%%% ind_fin = indices of last image of the range
ind_interruption=find((ind_test(2:length(ind_test))-ind_test(1:length(ind_test)-1))>3);
if(ind_test(length(ind_test))+1<length(num))
ind_debut=[1 ind_test(ind_interruption)+1 ind_test(length(ind_test))+1];
ind_fin=[ind_test(1)-1 ind_test(ind_interruption+1)-1 length(num)];
else
ind_debut=[1 ind_test(ind_interruption)+1];
ind_fin=[ind_test(1)-1 ind_test(ind_interruption+1)-1];
end
else
ind_debut=[1];
ind_fin=[length(num)];
end

N_file=length(ind_debut)

%%% compteur : index for the series of successive images that will be processed together. 
%%% In this series,the number of larvae detected either remains stable or increase
for compteur=1:length(ind_debut)

numero_initial = ind_debut(compteur);
nbimage= ind_fin(compteur);
%% trajectoire_abandonnee : number of larvae which tracks is stopped
trajectoire_abandonnee=[0];

%% create as many track variables as the number of larvae detected on first image of the series 
%% and store (x,y) location of each larvae in it
  for numobjet=1:num(numero_initial)
  eval(['track' num2str(numobjet) '=[' num2str(barycentre(numobjet,:,numero_initial)) '];' ]);
  end

%%% nbtrajectoire : number of opened tracks i.e. that should be updated with a new larva position 
%%% initial value is set to number of larvae detected on first image of the series
nbtrajectoire = num(numero_initial);

%%% scan the succession of images
for P=numero_initial+1:nbimage
    clear distance
%% scan all opened tracks
    for numobjet1=1:nbtrajectoire
    	for numobjet2=1:num(P)
            eval(['[nligne,inter]=size(track' num2str(numobjet1) ');' ]);   
            eval(['lastpos=track' num2str(numobjet1) '(nligne,:);' ]);   
            X = (lastpos(1)-barycentre(numobjet2,1,P));
           Y = (lastpos(2)-barycentre(numobjet2,2,P));
%% distance: matrix containing distances between all objects detected in the current image and 
%% last positions in the different opened tracks  
           distance(numobjet1,numobjet2) = sqrt((X^2)+(Y^2));
       end
   end
%   distance

%%% find the closest objects in the current image to last position in the opened tracks
   [c,d] = min(distance,[],2)
%%% store the index of any track in which a big jump is found OR of already stopped track
%%% in the variable trajectoire_abandonnee
   ind_stop=find((c>deplacement_max)|(isnan(c)==1));
    c(ind_stop)=NaN;
    d(ind_stop)=NaN;
    trajectoire_abandonnee=[find(isnan(c)==1)] 

%%% seek for objects in image P that are linked to a same track
doublon=uint32([0]);                     
for k=1:nbtrajectoire                          
	for m = k+1:nbtrajectoire		
		if ((d(k) == d(m))&(min(abs(doublon==d(k)))==0))
		doublon = [doublon;d(k)];                        
		end
	end
end

nb_doublon=0;
for j=2:length(doublon)
ind_doublon = find(d == doublon(j));         
[x,ind] =min(c(ind_doublon));
%%% detect non moving objects
if (x==0)
  ind2=ind(2:length(ind));
else
  ind2=find(c(ind_doublon)>x);
end
%%% store the index of any track that was linked to 2 different objects in the current image
%%% in the variable trajectoire_abandonnee
  trajectoire_abandonnee=[trajectoire_abandonnee; ind_doublon(ind2)];
  nb_doublon=nb_doublon+size(ind_doublon(ind2),1);

end

%%%%% decide wether to stop or complement an opened track
	    for numobjet =1:nbtrajectoire
%%% stop track if already stopped OR if object can be related to 2 tracks OR unrealistic jump 
	      if ((min(abs(trajectoire_abandonnee-numobjet)) == 0)|(isnan(c(numobjet))==1))
                eval(['track' num2str(numobjet) '=[track' num2str(numobjet) ';[NaN NaN] ];' ]);     
		else
%%% continue track by adding position of object in image P that have been linked univocally to an opened track
                eval(['track' num2str(numobjet) '=[track' num2str(numobjet) ';' num2str(barycentre(d(numobjet),:,P)) ' ];' ]);     
		end
	     end

%%% create new tracks with objects of image P that were not rlinked to already opened tracks
                nb_track=nbtrajectoire;
		for ind = 1:num(P)
 		inter = find(d == ind)
		   if (length(inter)== 0)
                   nb_track=nb_track+1;
	           eval(['track' num2str(nb_track) '=[' num2str(barycentre(ind,:,P)) ' ];' ]);       
		   end
		end

%%% update the number of opened tracks
nbtrajectoire = nb_track

end

%%% save tracks variables into file called track_filmX.dat
%%% X is the index for the series of successive images that were processed together
fid = fopen(['track_film' num2str(compteur) '.dat'],'wt');
	for numobjet = 1:nbtrajectoire
fprintf (fid,'%s \n', ['%track numero ' num2str(numobjet)]);
eval(['[nligne,inter]=size(track' num2str(numobjet) ');' ]);   
	for j = 1:nligne
fprintf (fid,'%7.3f  %7.3f\n', [eval(['track' num2str(numobjet) '(j,1)*scale_x']) eval(['track' num2str(numobjet) '(j,2)*scale_y']) ] ) ; 
	end
	end
fclose(fid);

end

end


