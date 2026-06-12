import ComposableArchitecture
import Foundation

@Reducer
enum ProfilePath {
  case detail(HomeDetailFeature)
  case likedFiltersList(LikedFiltersFeature)
  case creatorStore(CreatorStoreFeature)
  case makeView(MakeFeature)
  case userPostsList(UserPostsFeature)
  case likedPostsList(LikedPostsFeature)
  case editProfile(ProfileEditFeature)
  case preference(PreferenceFeature)
  case postDetail(PostDetailFeature)
  case userProfile(UserProfileFeature)
}

extension ProfilePath.State: Equatable {}
