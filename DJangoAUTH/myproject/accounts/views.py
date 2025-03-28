from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import authenticate, login
from .serializers import UserSerializer, LoginSerializer, VideoSerializer
from rest_framework.permissions import IsAuthenticated
from .models import Video
from rest_framework.parsers import MultiPartParser, FormParser

class RegisterView(APIView):
    def post(self, request):
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LoginView(APIView):
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            user = authenticate(username=serializer.validated_data['username'], password=serializer.validated_data['password'])
            if user:
                login(request, user)
                return Response({'message': 'Login successful'}, status=status.HTTP_200_OK)
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class VideoUploadView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    
    def post(self, request):
        # Create a mutable copy of the request data
        data = request.data.copy()
        
        # Add the video file from request.FILES
        if 'video_file' in request.FILES:
            data['video_file'] = request.FILES['video_file']
        else:
            return Response({'error': 'No video file provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Add thumbnail if available
        if 'thumbnail' in request.FILES:
            data['thumbnail'] = request.FILES['thumbnail']
        
        # Add user to the data (the currently authenticated user)
        data['user'] = request.user.id
        
        serializer = VideoSerializer(data=data, context={'request': request})
        if serializer.is_valid():
            video = serializer.save(user=request.user)
            return Response({
                'id': video.id,
                'title': video.title,
                'videoUrl': request.build_absolute_uri(video.video_file.url),
                'thumbnailUrl': request.build_absolute_uri(video.thumbnail.url) if video.thumbnail else None,
                'created_at': video.created_at
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class VideoListView(APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Get videos for the authenticated user
        videos = Video.objects.filter(user=request.user)
        serializer = VideoSerializer(videos, many=True, context={'request': request})
        return Response(serializer.data)