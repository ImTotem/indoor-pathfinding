pub mod common {
    tonic::include_proto!("indoor_pathfinding.common");
}

pub mod mapping {
    tonic::include_proto!("indoor_pathfinding.mapping");
}

pub mod localization {
    tonic::include_proto!("indoor_pathfinding.localization");
}

pub mod session {
    tonic::include_proto!("indoor_pathfinding.session");
}

pub mod service {
    tonic::include_proto!("indoor_pathfinding.service");
}
